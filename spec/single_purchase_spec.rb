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
    payment.amount_paid.should be_nil

    payment.purchase(:ip => '127.0.0.1').should be_true # make the purchase

    payment.should be_success
    payment.amount_paid.should == 15.95
  end
  
  it '#purchase should populate errors return false on error' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.invalid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.billing_address.update :name => 'remi taylor', :street => '101 Main St', :city => 'New York', :state => 'NY', 
                                   :country => 'USA', :zip => '12345'
    payment.amount = 15.95

    payment.should_not be_success
    payment.amount_paid.should be_nil
    payment.errors.should be_empty

    payment.purchase(:ip => '127.0.0.1').should be_false # make the purchase

    payment.errors.should_not be_empty
    payment.should_not be_success
    payment.amount_paid.should be_nil
  end

  it '#purchase! should raise exception on error' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.invalid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.billing_address.update :name => 'remi taylor', :street => '101 Main St', :city => 'New York', :state => 'NY', 
                                   :country => 'USA', :zip => '12345'
    payment.amount = 15.95

    payment.should_not be_success
    payment.amount_paid.should be_nil
    payment.errors.should be_empty

    lambda { payment.purchase!(:ip => '127.0.0.1') }.should raise_error(/Bogus Gateway: Forced failure/) # the error message

    payment.errors.should_not be_empty
    payment.should_not be_success
    payment.amount_paid.should be_nil
  end

  it 'handles credit card errors' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :number => TEST_HELPER.cc_number.invalid, # removed last name
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.amount = 15.95

    payment.purchase(:ip => '127.0.0.1').should be_false
    payment.errors.join(', ').should include('Last Name is required')
  end

  it 'handles #authorize/#capture errors' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.boom,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.billing_address.update :name => 'remi taylor', :street => '101 Main St', :city => 'New York', :state => 'NY', 
                                   :country => 'USA', :zip => '12345'
    payment.amount = 15.95

    payment.should_not be_success
    payment.amount_paid.should be_nil
    payment.errors.should be_empty

    payment.purchase(:ip => '127.0.0.1').should be_false

    payment.errors.should_not be_empty
    payment.errors.join(', ').should include('Bogus Gateway: Use CreditCard number 1 for success')
    payment.should_not be_success
    payment.amount_paid.should be_nil
  end

end
