require File.dirname(__FILE__) + '/../lib/ractivemerchant'
require 'rubygems'
require 'spec'
require 'rack/test'
require 'webrat'
require 'fakeweb'
require 'sinatra/base'

Webrat.configure do |config|
  config.mode = :rack
end

FakeWeb.allow_net_connect = false # just incase ActiveMerchant tries connecting ...

# Rack::Test doesn't give you a way to change the application  Oo
module Rack::Test::Methods
  def build_rack_mock_session
    Rack::MockSession.new(@_rack_app || app)
  end
  def set_rack_app app
    @_rack_app = app
    @_rack_mock_sessions = { :default => build_rack_mock_session }
  end
end

describe RActiveMerchant do
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers

  # A sample application (which we include the middleware in)
  def rack_app
    @rack_app ||= lambda {|env| [200, {}, ["Hello from app, env:\n" + env.to_yaml]] }
  end

  # A bogus gateway
  def gateway
    @gateway ||= ActiveMerchant::Billing::BogusGateway.new
  end

  # This is the application that rack-test will send all of its requests to, by default
  def app
    @app ||= RActiveMerchant.new rack_app, gateway
  end

  describe 'configuration' do

    before do
      set_rack_app @app
    end

    it 'requires a valid Rack application (that responds to #call)' do
      lambda { RActiveMerchant.new               }.should raise_error(ArgumentError, /wrong number of arguments \(0 for 2\)/)
      lambda { RActiveMerchant.new nil, gateway }.should raise_error(ArgumentError, /valid rack app/i)

      RActiveMerchant.new(rack_app, gateway).app.should == rack_app
    end

    it 'requires gateway (that responds to #purchase)' do
      lambda { RActiveMerchant.new rack_app      }.should raise_error(ArgumentError, /wrong number of arguments \(1 for 2\)/)
      lambda { RActiveMerchant.new rack_app, nil }.should raise_error(ArgumentError, /valid gateway/i)

      RActiveMerchant.new(rack_app, gateway).gateway.should == gateway
    end

    it 'can override the path_prefix used for all of the *default* paths' do
      ractivemerchant = RActiveMerchant.new rack_app, gateway
      ractivemerchant.path_prefix.should        == '/ractivemerchant'
      ractivemerchant.purchase_path.should      == '/ractivemerchant/purchase'
      ractivemerchant.purchase_form_path.should == '/ractivemerchant/purchase'
      ractivemerchant.on_success_path.should    == '/ractivemerchant/confirmation'
      ractivemerchant.on_error_path.should      == '/ractivemerchant/error'

      ractivemerchant.path_prefix = '/foo/bar/'
      ractivemerchant.path_prefix.should        == '/foo/bar/'
      ractivemerchant.purchase_path.should      == '/foo/bar/purchase'
      ractivemerchant.purchase_form_path.should == '/foo/bar/purchase'
      ractivemerchant.on_success_path.should    == '/foo/bar/confirmation'
      ractivemerchant.on_error_path.should      == '/foo/bar/error'
    end

    it 'can override purchase_path' do
      RActiveMerchant.new(rack_app, gateway).purchase_path.should == '/ractivemerchant/purchase'
      RActiveMerchant.new(rack_app, gateway, :purchase_path => '/buy-stuff').purchase_path.should == '/buy-stuff'
    end

    it 'can specify an on_success path for successful requests to be redirected to'

    it 'can specify an on_error path for only failed request to be redirected to (redirects BACK by default)'

    it 'can access instance of RActiveMerchant via env["rack.ractivemerchant"]' do
      get '/'
      last_response.body.should include('rack.ractivemerchant.instance: !ruby/object:RActiveMerchant')
    end

    it 'can override the env variable name for storing the instance of RAcktiveMerchant' do
      set_rack_app RActiveMerchant.new(rack_app, gateway, :instance_env_variable => 'hello-there')

      get '/'
      last_response.body.should_not include('rack.ractivemerchant.instance: !ruby/object:RActiveMerchant')
      last_response.body.should     include('hello-there: !ruby/object:RActiveMerchant')
    end

    # just use purchase path?
    it 'can override the purchase_form_path (where we display a sample form.  defaults to purchase_path)'

    it 'can disable the included purchase_form altogether so it will not be displayed'

    it 'can disable the included confirmation page (on_success) altogether so it will not be displayed'

  end

  describe 'purchasing' do

    it 'should redirect to on_success when credit card is valid and purchase is successful'

    it 'should do something smart when no referrer is found (redirect to the purchase form path?)'

    it 'should redirect back (or to on_error) when not all required fields are submitted' do
      post '/ractivemerchant/purchase', :body => { :credit_card_number => '1' }
      last_response.body.should include('Hello from app') # should call the rack app
      last_response.body.should include('credit_card_cvv is required')
    end

    it 'should redirect back (or to on_error) when credit card is not valid'

    it 'should redirect back (or to on_error) when purchase is unsuccessful'

  end

  describe 'filling out sample form' do

    it 'should come with a same form that your application can use by doing a GET to purchase_path'

    it 'should display errors (when not all required fields are submitted)'
    
    it 'should display errors (when credit card is not valid)'

    it 'should display errors (when purchase is unsuccessful)'

    it 'should redirect OK to on_success (with information about the transaction provided) on success'

  end

  describe 'high level integration' do

    it 'should be able to make a successful purchase (MOST IMPORTANT)' do
      pending 'refactoring, then coming back to this'
      class SimpleApp < Sinatra::Base
        use RActiveMerchant, ActiveMerchant::Billing::BogusGateway.new

        get '/' do
          %{
            <form action='/' method='post'>
              <input type='text' id='monies' name='monies' />
              <input type='submit' value='Checkout' />
            </form>
          }
        end

        post '/' do
          [ 402, { 'Payment-Amount' => "#{ params[:monies] } USD" }, ['Payment Required'] ] # 402 Payment Required:w
        end
      end

      set_rack_app SimpleApp.new

      # visit some fake page where we 'checkout' from to start the middleware process!
      visit '/'
      fill_in :monies, :with => 9.95
      click_button 'Checkout'

      # this should take us to either the app's screen or the checkout screen we supply out of the box      

      # credit card
      { 
        :first_name       => 'remi',
        :last_name        => 'taylor',
        :number           => '1',     # 1 is valid using the BogusGateway
        :cvv              => '123',
        :expiration_month => '01',
        :expiration_year  => '2015' 
      }.each { |key, value| fill_in "credit_card_#{key}", :with => value.to_s }

      # billing address
      { 
        :name     => 'remi',
        :address1 => '123 Chunky Bacon St.',
        :city     => 'Magical Land',
        :state    => 'NY',
        :country  => 'US',
        :zip      => '12345'
      }.each { |key, value| fill_in "billing_address_#{key}", :with => value.to_s }

      click_button 'Purchase'

      # if all went well, we should be on the order confirmation page ... the app's or one in the middleware

      last_response.should include('Order successful')
      last_response.should include('9.95')
    end

  end

end
