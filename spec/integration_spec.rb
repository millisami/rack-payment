require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'integration' do
  include IntegrationSpec

  it 'should be able to make a successful purchas' do
    set_rack_app SimpleApp.new

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
    set_rack_app SimpleApp.new

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
    set_rack_app SimpleApp.new

    visit '/'
    fill_in :monies, :with => 9.95
    click_button 'Checkout'

    fill_in_invalid_credit_card
    fill_in_valid_billing_address
    click_button 'Purchase'

    last_response.should_not contain('Order successful')
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

  it 'should get errors if calling authorize blows up (and it lets us fix it)' do
    set_rack_app SimpleApp.new

    visit '/'
    fill_in :monies, :with => 9.95
    click_button 'Checkout'

    fill_in_valid_credit_card :number => '3' # 3 throws an exception
    fill_in_valid_billing_address
    click_button 'Purchase'

    last_response.should_not contain('Order successful')
    last_response.should contain('Bogus Gateway: Use CreditCard number 1 for success') # <--- part of the exception message

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
    last_response.body.should include('@params={"authorized_amount"=>"995"}') # part of authorization response
    last_response.body.should include('@params={"paid_amount"=>"995"}')       # part of capture response
  end

  it 'should be able to use my own page(s) for filling out credit card / billing info' do
    set_rack_app SimpleAppWithOwnCreditCardPage.new

    visit '/'
    last_response.should contain('Custom Page')
    fill_in :monies, :with => 15.95 # it has the money and credit card info, all on the same page

    # custom form with different field names ...
    { 
      :first_name       => 'remi',
      :last_name        => 'taylor',
      :number           => '1',     # 1 is valid using the BogusGateway
      :cvv              => '123',
      :expiration_month => '01',
      :expiration_year  => '2015',
      :type             => 'visa'
    }.each { |key, value| fill_in "credit_card[#{key}]", :with => value.to_s }
    { 
      :name     => 'remi',
      :address1 => '123 Chunky Bacon St.',
      :city     => 'Magical Land',
      :state    => 'NY',
      :country  => 'US',
      :zip      => '12345'
    }.each { |key, value| fill_in "address[#{key}]", :with => value.to_s }

    click_button 'Purchase'

    last_response.should contain('Order successful')
    last_response.should contain('15.95')
  end

  it 'if i use my own page for filling out credit card / billing info, that page should be re-rendered if errors occur (and can fix errors)' do
    set_rack_app SimpleAppWithOwnCreditCardPage.new

    visit '/'
    last_response.should contain('Custom Page')
    fill_in :monies, :with => 15.95 # it has the money and credit card info, all on the same page

    # custom form with different field names ...
    { 
      :first_name       => 'remi',
      :last_name        => 'taylor',
      :number           => '2',     # 2 is invalid using the BogusGateway
      :cvv              => '123',
      :expiration_month => '01',
      :expiration_year  => '2015',
      :type             => 'visa'
    }.each { |key, value| fill_in "credit_card[#{key}]", :with => value.to_s }
    { 
      :name     => 'remi',
      :address1 => '123 Chunky Bacon St.',
      :city     => 'Magical Land',
      :state    => 'NY',
      :country  => 'US',
      :zip      => '12345'
    }.each { |key, value| fill_in "address[#{key}]", :with => value.to_s }

    click_button 'Purchase'

    last_response.should_not contain('Order successful')
    last_response.should contain('failure')
    last_response.should contain('Custom Page')

    fill_in 'credit_card[number]', :with => '1' # <--- valid number
    click_button 'Purchase'

    last_response.should contain('Order successful') # regular old order successful page
    last_response.should contain('15.95')
  end

  it 'should be able to specify a different page to go to on_error (which can display the error message(s))'

end
