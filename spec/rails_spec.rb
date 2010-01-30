require File.dirname(__FILE__) + '/spec_helper'

describe 'Example Rails app' do
  include IntegrationSpec

  before do
    set_rack_app RAILS_APP
  end

  it 'should list products on home page' do
    visit '/'
    last_response.should_not contain('Twinkie')

    Product.create :name => 'Twinkie', :cost => 0.95

    visit '/'
    last_response.should contain('Twinkie')
  end

  it 'should work' do
    Product.create :name => 'Cookie', :cost => 4.95

    visit '/'
    click_link 'Cookie'
    click_link 'BUY!'
    
    last_response.should contain('Custom Credit Card View')
    fill_in_valid_credit_card :number => nil
    fill_in_valid_billing_address
    click_button 'Complete Purchase'

    last_response.should contain('Custom Credit Card View')
    last_response.should contain('Number is required')

    fill_in :credit_card_number, :with => '1'
    click_button 'Complete Purchase'

    last_response.should contain('Custom Order Confirmation page!')
    last_response.should contain('You bought a Cookie for $4.95')
  end

end
