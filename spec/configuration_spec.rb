require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'configuration' do

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

  it 'should check for config/[something].yml by default, if no hash passed'

end
