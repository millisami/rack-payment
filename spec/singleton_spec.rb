require File.dirname(__FILE__) + '/spec_helper'

describe 'Singleton-ish behavior' do

  it 'tracks all launched instances and you can get the current "instance"' do
    Rack::Payment.instances.clear
    Rack::Payment.instances.length.should == 0
    
    a = Rack::Payment.new
    Rack::Payment.instances.length.should == 1
    Rack::Payment.instances.should        == [a]
    Rack::Payment.instance.should         == a

    b = Rack::Payment.new
    Rack::Payment.instances.length.should == 2
    Rack::Payment.instances.should        == [a, b]
    lambda { Rack::Payment.instance }.should raise_error(/one/i)

    first = Rack::Payment.instances.shift
    Rack::Payment.instances.length.should == 1
    Rack::Payment.instances.should        == [b]
    Rack::Payment.instance.should         == b
  end

end
