require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'default UI' do
  include IntegrationSpec

  # For every one of these examples, we go ahead and visit 
  # the home page of SimpleApp and fill in an amount of 
  # money that we want to spend and call 'Checkout' 
  # which will render the default Rack::Purchase 
  # billing info page so we can enter our credit card info.
  before do
    set_rack_app SimpleApp.new

    visit '/'
    fill_in :monies, :with => 9.95
    click_button 'Checkout'
  end

  it 'can make a purchase' do
    fill_in_valid_credit_card
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should contain('Order successful')
    last_response.should contain('9.95')
  end

  it 'errors are displayed if not all required fields are filled out [and we can fix it]' do
    fill_in_valid_credit_card :first_name => nil
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should     contain('First Name is required')
    last_response.should_not contain('Order successful')

    # Make sure #authorize is called with the right arguments (we return what it normally would)
    a_gateway = ActiveMerchant::Billing::BogusGateway.new
    SimpleApp.gateway.should_receive(:authorize).
      with(995, anything, :ip => '127.0.0.1', :billing_address => billing_address_hash).
      and_return {|*args| a_gateway.authorize(*args) }

    fill_in :credit_card_type, :with => 'visa' # because Webrat is hating on me
    fill_in :credit_card_first_name, :with => 'remi'
    fill_in :credit_card_type,   :with => 'visa'
    click_button 'Complete Purchase'

    last_response.should     contain('Order successful')
    last_response.should     contain('9.95')
    last_response.should_not contain('First Name is required')
  end

  it 'errors are displayed if credit card is invalid [and we can fix it]' do
    fill_in_invalid_credit_card
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should     contain('failure')
    last_response.should_not contain('Order successful')

    # Make sure #capture is called with the right arguments (we return an acceptable response)
    a_gateway = ActiveMerchant::Billing::BogusGateway.new
    SimpleApp.gateway.should_receive(:capture).with(995, anything).
      and_return { a_gateway.capture(995, "success") }

    fill_in :credit_card_number, :with => TEST_HELPER.cc_number.valid
    fill_in :credit_card_type,   :with => 'visa'
    click_button 'Complete Purchase'

    last_response.should     contain('Order successful')
    last_response.should     contain('9.95')
    last_response.should_not contain('failure')
  end

  it 'errors are displayed if #capture raises exception' do
    authorize_response = OpenStruct.new :success? => true, :authorization => TEST_HELPER.auth.boom
    SimpleApp.gateway.should_receive(:authorize).with(995, anything, :ip => '127.0.0.1', :billing_address => billing_address_hash).
      and_return(authorize_response)

    fill_in_valid_credit_card
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should_not contain('Order successful')
    last_response.should     contain('Bogus Gateway: Forced failure')
  end

  it 'should handle when #authorize raises exception [and we can fix it]' do
    fill_in_valid_credit_card :number => TEST_HELPER.cc_number.boom
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should_not contain('Order successful')
    last_response.should     contain('Bogus Gateway: Use CreditCard number 1 for success')

    fill_in :credit_card_number, :with => TEST_HELPER.cc_number.valid
    fill_in :credit_card_type,   :with => 'visa'
    click_button 'Complete Purchase'

    last_response.should     contain('Order successful')
    last_response.should     contain('9.95')
    last_response.should_not contain('Bogus Gateway: Use CreditCard number 1 for success')
  end

end
