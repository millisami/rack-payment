require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'configuration' do

  def can_get_and_set_attribute name, default = nil, value = '/foo'
    name = name.to_s.to_sym

    Rack::Payment.new(@app, :gateway => 'bogus'                ).send(name).should == default
    Rack::Payment.new(@app, :gateway => 'bogus', name => value).send(name).should == value

    payment = Rack::Payment.new(@app, :gateway => 'bogus')
    payment.send(name).should == default

    payment.send("#{name}=", value)
    payment.send(name).should == value
    
    # can also set to nil
    payment.send("#{name}=", nil)
    payment.send(name).should == nil
  end

  before do
    @app = lambda { }
  end

  it 'requires a valid Rack application (that responds to #call)' do
    lambda { Rack::Payment.new               }.should raise_error(ArgumentError, /wrong number of arguments \(0 for 2\)/)
    lambda { Rack::Payment.new nil, :bogus }.should raise_error(ArgumentError, /valid rack app/i)

    Rack::Payment.new(@app, :bogus).app.should == @app
  end

  it 'requires gateway (name and options)' do
    lambda { Rack::Payment.new @app      }.should raise_error(ArgumentError, /wrong number of arguments \(1 for 2\)/)
    lambda { Rack::Payment.new @app, nil }.should raise_error(ArgumentError, /valid gateway/i)

    Rack::Payment.new(@app, 'bogus').gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app, :bogus ).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app, :bogus, :foo => 'bar').gateway_options.should == { :foo => 'bar' }
  end

  it 'can take a hash where the gateway type is passed as :gateway (for easy YML loading)' do
    Rack::Payment.new(@app, :gateway => 'bogus').gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
  end

  it 'can set the path to be used on_success' do
    can_get_and_set_attribute :on_success
  end

  it 'can set the path that the built-in credit card / billing address form POSTs to' do
    can_get_and_set_attribute :built_in_form_path, '/rack.payment/process'
  end

  it 'can set the path that express payments should return to (when OK)' do
    can_get_and_set_attribute :express_ok_path, '/rack.payment/express.callback/ok'
  end

  it 'can set the path that express payments should return to (when payment is canceled)' do
    can_get_and_set_attribute :express_cancel_path, '/rack.payment/express.callback/cancel'
  end

  it 'can set the name of the env[] variable that the Rack::Payment instance is made available in' do
    can_get_and_set_attribute :env_instance_variable, 'rack.payment'
  end

  it 'can set the name of the env[] variable that the Rack::Payment::Data instance is made available in' do
    can_get_and_set_attribute :env_data_variable, 'rack.payment.data'
  end

  it 'can set the name of the session variable that Rack::Payment uses to persist data that needs to be persisted betweetn requests' do
    can_get_and_set_attribute :session_variable, 'rack.payment'
  end

  it 'can set the name of the variable used to access the Rack::Session' do
    can_get_and_set_attribute :rack_session_variable, 'rack.session'
  end

  it 'can set the path to the view to be rendered (credit card & billing info)'

  it 'should check for config/[something].yml by default, if no hash passed'

end
