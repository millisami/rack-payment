require File.dirname(__FILE__) + '/spec_helper'

# We're basically testing to confirm that the BogusGateway works as advertised.
#
# This is important because we make a BogusExpressGateway for testing PayPal Express 
# and we want to make sure that the gateways work exactly the way we think they do!

describe ActiveMerchant::Billing::BogusGateway do

  describe '#authorize' do
    
    it 'should be successful if the credit card number is 1'
    it 'should not be if the credit card number is 2'
    it 'should raise exception if the credit card number is 3'

  end

  describe '#capture' do

  end

end
