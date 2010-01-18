require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'configuration' do

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
