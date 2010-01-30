require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'configuration' do

  after do
    ActiveMerchant::Billing::Base.mode = :test
    ENV["RACK_ENV"] = 'test' # just incase we mess it up
  end

  def can_get_and_set_attribute name, default = nil, value = '/foo'
    name = name.to_s.to_sym

    Rack::Payment.new(@app, :gateway => 'bogus'               ).send(name).should == default
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
    @yml_file_names = Rack::Payment.yml_file_names
  end

  after do
    Rack::Payment.yml_file_names = @yml_file_names
  end

  it 'requires a valid Rack application (that responds to #call)' do
    # if you pass nil, we assume that there is no rack app
    lambda { Rack::Payment.new 'something invalid besides nil', :gateway => :bogus }.should raise_error(ArgumentError, /valid rack app/i)
    Rack::Payment.new(@app, 'gateway' => :bogus).app.should == @app
  end

  it 'requires a valid Gateway' do
    Rack::Payment.yml_file_names = []

    lambda { Rack::Payment.new @app, :gateway => nil }.should raise_error(ArgumentError, /valid gateway/i)
    lambda { Rack::Payment.new @app, :gateway => 'foo' }.should raise_error(ArgumentError, /valid gateway/i)
    lambda { Rack::Payment.new @app, :gateway => :bogus }.should_not raise_error

    Rack::Payment.new(@app, :gateway => :bogus).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
  end

  it 'should check for config/[something].yml by default, if no hash passed' do
    Rack::Payment.yml_file_names = []
    lambda { Rack::Payment.new(@app) }.should raise_error(ArgumentError, /must pass options/i)

    tmpfile = Tempfile.new 'yaml-file2'
    tmpfile.print ''
    tmpfile.close
    Rack::Payment.yml_file_names = [tmpfile.path]
    lambda { Rack::Payment.new(@app) }.should raise_error(ArgumentError, /must pass options/i)

    tmpfile = Tempfile.new 'yaml-file1'
    tmpfile.print({ :gateway => :bogus, 'foo' => 'bar' }.to_yaml)
    tmpfile.close
    Rack::Payment.yml_file_names = [tmpfile.path]
    Rack::Payment.new(@app).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app).gateway_options['foo'].should == 'bar'
  end

  it 'should will actually look for a yml file regardless, and will merge options unless :yml_config => false' do
    tmpfile = Tempfile.new 'yaml-file1'
    tmpfile.print({ :gateway => :bogus, :foo => 'bar' }.to_yaml)
    tmpfile.close
    Rack::Payment.yml_file_names = [tmpfile.path]
    
    Rack::Payment.new(@app).on_success.should be_nil
    Rack::Payment.new(@app, :on_success => '/foo').on_success.should == '/foo'

    # passing a :gateway should OVERRIDE the one from yml
    lambda { Rack::Payment.new(@app, :gateway => 'no-exist') }.should raise_error(/valid gateway/i)

    Rack::Payment.new(@app, :gateway => :bogus).gateway_options[:foo].should == 'bar'
    Rack::Payment.new(@app, :gateway => :bogus, :yml_config => false).gateway_options[:foo].should be_nil
  end

  it 'should remove the Rack::Payment options from options passed so they do not make it into gateway_options' do
    Rack::Payment.new(@app, :gateway => 'bogus', :foo => 'bar').gateway_options[:foo].should == 'bar'
    Rack::Payment.new(@app, :gateway => 'bogus', :on_success => '/foo').gateway_options['on_success'].should be_nil
  end

  it 'supports yml configuration files with environments (if ENV["RACK_ENV"] is set and it matches one of the keys)' do
    tmpfile = Tempfile.new 'yaml-file1'
    tmpfile.print({ 'test' => { :gateway => :bogus, :foo => 'bar' }}.to_yaml)
    tmpfile.close
    Rack::Payment.yml_file_names = [tmpfile.path]

    ENV["RACK_ENV"] = nil
    lambda { Rack::Payment.new(@app) }.should raise_error(/valid gateway/i)

    ENV["RACK_ENV"] = 'test'
    Rack::Payment.new(@app).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app).gateway_options[:foo].should == 'bar'
  end

  it 'supports yml configuration files with environments (if ENV["RAILS_ENV"] is set and it matches one of the keys)' do
    ENV["RACK_ENV"] = nil # because we look for RACK_ENV first

    tmpfile = Tempfile.new 'yaml-file1'
    tmpfile.print({ 'test' => { :gateway => :bogus, :foo => 'bar' }, 'test2' => { :gateway => :bogus, :foo => 'HI' }}.to_yaml)
    tmpfile.close
    Rack::Payment.yml_file_names = [tmpfile.path]

    lambda { Rack::Payment.new(@app) }.should raise_error(/valid gateway/i)

    ENV["RAILS_ENV"] = 'test'
    Rack::Payment.new(@app).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app).gateway_options[:foo].should == 'bar'

    ENV["RACK_ENV"] = 'test2'
    Rack::Payment.new(@app).gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
    Rack::Payment.new(@app).gateway_options[:foo].should == 'HI' # RACK_ENV takes precedence

    ENV["RACK_ENV"] = 'test'
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
    can_get_and_set_attribute :env_helper_variable, 'rack.payment.helper'
  end

  it 'can set the name of the session variable that Rack::Payment uses to persist data that needs to be persisted betweetn requests' do
    can_get_and_set_attribute :session_variable, 'rack.payment'
  end

  it 'can set the name of the variable used to access the Rack::Session' do
    can_get_and_set_attribute :rack_session_variable, 'rack.session'
  end

  it 'can set the path to the view to be rendered (credit card & billing info)'

  it 'can configure what the ActiveMerchant::Billing::Base.mode is set to via test_mode = true/false' do
    # individual gateways don't seem to have a mode, so we have to change it globally

    Rack::Payment.new(nil, :gateway => 'bogus', :test_mode => false)
    ActiveMerchant::Billing::Base.mode.should == :production

    Rack::Payment.new(nil, :gateway => 'bogus', :test_mode => true )
    ActiveMerchant::Billing::Base.mode.should == :test

    Rack::Payment.new(nil, :gateway => 'bogus', :test_mode => false)
    ActiveMerchant::Billing::Base.mode.should == :production

    # by default, if you don't pass a mode, it doesn't change the mode
    Rack::Payment.new(nil, :gateway => 'bogus')
    ActiveMerchant::Billing::Base.mode.should == :production
  end

end
