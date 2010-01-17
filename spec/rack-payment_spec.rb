require File.dirname(__FILE__) + '/../lib/rack/payment'
%w( rubygems spec rack/test webrat fakeweb sinatra/base ).each {|lib| require lib }

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

# todo ... move example apps to different files?  maybe?
class SimpleApp < Sinatra::Base

  class << self
    attr_accessor :gateway
  end

  @gateway = ActiveMerchant::Billing::BogusGateway.new

  use Rack::Session::Cookie # <-- needs to blow up if this isn't available
  use Rack::Payment, gateway

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    %{
      <form action='/' method='post'>
        <input type='text' id='monies' name='monies' />
        <input type='submit' value='Checkout' />
      </form>
     }
  end

  post '/' do
    payment.amount = params[:monies]
    [ 402, {}, ['Payment Required'] ]
  end
end

class SimpleAppWithOnSuccessOverridden < Sinatra::Base

  class << self
    attr_accessor :gateway
  end

  @gateway = ActiveMerchant::Billing::BogusGateway.new

  use Rack::Session::Cookie # <-- needs to blow up if this isn't available
  use Rack::Payment, gateway, :on_success => '/custom_success_page'

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    %{
      <form action='/' method='post'>
        <input type='text' id='monies' name='monies' />
        <input type='submit' value='Checkout' />
      </form>
     }
  end

  post '/' do
    payment.amount = params[:monies]
    [ 402, {}, ['Payment Required'] ]
  end

  get '/custom_success_page' do
    "w00t!  Success!  You should have been charged #{ payment.amount } (#{ payment.amount_in_cents }).  " + 
    "Raw capture response: #{ payment.capture_response.inspect }.  " + 
    "Raw authoriziation request: #{ payment.authorize_response.inspect }"
  end
end

def fill_in_invalid_credit_card fields = {}
  fill_in_credit_card({:number => '2'}.merge(fields))
end

def fill_in_valid_credit_card fields = {}
  fill_in_credit_card({:number => '1'}.merge(fields))
end

def fill_in_credit_card fields = {}
  { 
    :first_name       => 'remi',
    :last_name        => 'taylor',
    :number           => '1',     # 1 is valid using the BogusGateway
    :cvv              => '123',
    :expiration_month => '01',
    :expiration_year  => '2015',
    :type             => 'visa'
  }.merge(fields).each { |key, value| fill_in "credit_card_#{key}", :with => value.to_s }
end

def fill_in_valid_billing_address
  { 
    :name     => 'remi',
    :address1 => '123 Chunky Bacon St.',
    :city     => 'Magical Land',
    :state    => 'NY',
    :country  => 'US',
    :zip      => '12345'
  }.each { |key, value| fill_in "billing_address_#{key}", :with => value.to_s }
end

describe Rack::Payment do

  # for integration testing
  include Rack::Test::Methods
  include Webrat::Methods
  include Webrat::Matchers


  describe 'configuration' do

    before do
      @app     = lambda { }
      @gateway = ActiveMerchant::Billing::BogusGateway.new
    end

    it 'requires a valid Rack application (that responds to #call)' do
      lambda { Rack::Payment.new               }.should raise_error(ArgumentError, /wrong number of arguments \(0 for 2\)/)
      lambda { Rack::Payment.new nil, @gateway }.should raise_error(ArgumentError, /valid rack app/i)

      Rack::Payment.new(@app, @gateway).app.should == @app
    end

    it 'requires gateway (that responds to #purchase)' do
      lambda { Rack::Payment.new @app      }.should raise_error(ArgumentError, /wrong number of arguments \(1 for 2\)/)
      lambda { Rack::Payment.new @app, nil }.should raise_error(ArgumentError, /valid gateway/i)

      Rack::Payment.new(@app, @gateway).gateway.should == @gateway
    end

  end

  describe 'high level integration' do

    before do
      @app = SimpleApp.new
      set_rack_app @app
    end

    it 'should be able to make a successful purchase (MOST IMPORTANT)' do
      visit '/'
      fill_in :monies, :with => 9.95
      click_button 'Checkout'

      fill_in_valid_credit_card
      fill_in_valid_billing_address
      click_button 'Purchase'

      last_response.should contain('Order successful')
      last_response.should contain('9.95')
    end

    it 'should get errors if not all required fields are given (and it lets us fix the fields)' do
      visit '/'
      fill_in :monies, :with => 9.95
      click_button 'Checkout'

      fill_in_valid_credit_card :first_name => nil
      fill_in_valid_billing_address
      click_button 'Purchase'

      last_response.should_not contain('Order successful')
      last_response.should contain('first_name is required')

      # make sure it gets called with the right amount ... we're not checking the credit card at the moment ...
      a_gateway = ActiveMerchant::Billing::BogusGateway.new
      SimpleApp.gateway.should_receive(:authorize).with(995, anything).and_return {|*args| a_gateway.authorize(*args) }

      fill_in :credit_card_first_name, :with => 'remi'
      click_button 'Purchase'

      last_response.should contain('Order successful')
      last_response.should contain('9.95')
    end

    it 'should get errors if the credit card is not valid (and it lets us fix it)' do
      visit '/'
      fill_in :monies, :with => 9.95
      click_button 'Checkout'

      fill_in_invalid_credit_card
      fill_in_valid_billing_address
      click_button 'Purchase'

      last_response.should_not contain('Order successful')
      #last_response.should contain('Invalid credit card')
      last_response.should contain('failure')

      # make sure capture gets called with the right amount
      # Use authorization number 1 for exception, 2 for error and anything else for success
      a_gateway = ActiveMerchant::Billing::BogusGateway.new
      SimpleApp.gateway.should_receive(:capture).with(995, anything).and_return { a_gateway.capture(995, "success") }

      fill_in :credit_card_number, :with => '1' # <--- valid number
      click_button 'Purchase'

      last_response.should contain('Order successful')
      last_response.should contain('9.95')
    end

    it 'should get errors if there was a problem capturing payment'

    it 'should be able to specify a different page to render on_success (which can display the transaction response)' do
      set_rack_app SimpleAppWithOnSuccessOverridden.new

      visit '/'
      fill_in :monies, :with => 9.95
      click_button 'Checkout'

      fill_in_invalid_credit_card
      fill_in_valid_billing_address
      click_button 'Purchase'

      last_response.should_not contain('Order successful')
      #last_response.should contain('Invalid credit card')
      last_response.should contain('failure')

      fill_in :credit_card_number, :with => '1' # <--- valid number
      click_button 'Purchase'

      last_response.should_not contain('Order successful')
      last_response.should contain('w00t!  Success!')
      last_response.should contain('9.95 (995)')
      last_response.should contain('@params={"authorized_amount"=>"995"}, @success=true') # part of authorization response
      last_response.should contain('@params={"paid_amount"=>"995"}, @success=true')       # part of capture response
    end

    it 'should be able to specify a different page to go to on_error (which can display the error message(s))'

  end

end
