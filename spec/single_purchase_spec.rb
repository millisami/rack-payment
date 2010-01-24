require File.dirname(__FILE__) + '/spec_helper'

describe 'Single Purchase (without web app)' do

  it 'Can find the gateway' do
    payment = Rack::Payment.new.payment
    payment.gateway.should be_a(ActiveMerchant::Billing::BogusGateway)
  end

  it 'can fire off a single OK purchase and get response OK' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.valid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.billing_address.update :name => 'remi taylor', :street => '101 Main St', :city => 'New York', :state => 'NY', 
                                   :country => 'USA', :zip => '12345'
    payment.amount = 15.95

    payment.should_not be_success
    payment.amount_paid.should == nil

    payment.purchase(:ip => '127.0.0.1').should == true # make the purchase

    payment.should be_success
    payment.amount_paid.should == 15.95
  end
  
  it '#purchase should populate errors return false on error'

  it '#purchase! should raise exception on error'

  it 'handles credit card errors'

  it 'handles #authorize/#capture errors'

end
