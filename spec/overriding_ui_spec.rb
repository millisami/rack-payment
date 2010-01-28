require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'overriding UI' do
  include IntegrationSpec

  it 'can specify a different page to render on_success (which can display the transaction response)' do
    set_rack_app SimpleAppWithOnSuccessOverridden.new

    visit '/'
    fill_in :monies, :with => 9.95
    click_button 'Checkout'

    fill_in_invalid_credit_card
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should_not contain('Order successful')
    last_response.should contain('failure')

    fill_in :credit_card_number, :with => '1' # <--- valid number
    fill_in :credit_card_type, :with => 'visa'
    click_button 'Complete Purchase'

    last_response.should_not contain('Order successful')

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

    click_button 'Complete Purchase'

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
      :number           => '2',    # 2 = invalid
      :cvv              => '123',
      :expiration_month => '01',
      :expiration_year  => '2015',
      :type             => 'visa'
    }.each { |key, value| fill_in "credit_card[#{key}]", :with => value.to_s }

    # we forgot the cvv and didn't fill out the address

    click_button 'Complete Purchase'

    last_response.should contain('payment.amount: 15.95')
    last_response.should contain('payment.amount_paid: nil')
    last_response.should_not contain('Order successful')
    last_response.should contain('failure')
    last_response.should contain('Custom Page')

    fill_in 'credit_card[number]', :with => '1' # <--- valid number
    click_button 'Complete Purchase'

    last_response.should contain('Order successful') # regular old order successful page
    last_response.should contain('15.95')
    last_response.should contain('payment.amount: 15.95')
    last_response.should contain('payment.amount_paid: 15.95')
  end

  it 'should be able to use your own layout and spit out the html for the form inside it' do
    set_rack_app SimpleAppWithOwnLayout.new

    visit '/?amount=1.50'
    last_response.should contain('Here be my form!') # custom text
    fill_in_invalid_credit_card
    click_button 'Complete Purchase'

    last_response.should contain('payment.amount: 1.5')
    last_response.should contain('payment.amount_paid: nil')
    last_response.should_not contain('Order successful')
    last_response.should contain('failure')
    last_response.should contain('Custom Page')

    fill_in_valid_credit_card
    click_button 'Complete Purchase'

    last_response.should contain('Order successful') # regular old order successful page
    last_response.should contain('payment.amount: 1.5')
    last_response.should contain('payment.amount_paid: 1.5')
  end

  it 'should not add any in-line css' do
    set_rack_app SimpleAppWithOwnLayout.new

    visit '/?amount=1.50'

    last_response.body.should_not include('<style')
  end

  it 'should be able to specify a different page to go to on_error (which can display the error message(s))'

end
