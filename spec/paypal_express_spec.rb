require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment, 'PayPal Express' do
  include IntegrationSpec

  before do
    set_rack_app SimpleAppWithPayPalExpress.new
  end

  it 'can make a purchase normally (without PayPal Express)' do
    visit '/'
    fill_in :monies, :with => 9.95
    click_button 'Checkout'

    fill_in_valid_credit_card
    fill_in_valid_billing_address
    click_button 'Purchase'

    last_response.should contain('Order successful')
    last_response.should contain('9.95')
  end

  it 'can make a purchase via PayPal Express' do
    visit '/'

    # should have access to the Rack::Purchase instance ...
    klass = SimpleAppWithPayPalExpress
    klass.rack_payment_instance.should                        be_a(Rack::Payment)
    klass.rack_payment_instance.gateway.should                be_a(ActiveMerchant::Billing::BogusGateway)
    klass.rack_payment_instance.express_gateway.should be_a(ActiveMerchant::Billing::BogusExpressGateway)

    fill_in :monies, :with => 9.95
    click_button 'Checkout with PayPal'

    # should be redirected to the appropriate PayPal URL to actually fill stuff out.
    # if we cancel, it will redirect us back to X url.
    # if we don't,  it will redirect us back to Y url.
    last_response.location.should == '... some paypal url ... ?'

    visit '/the-url-paypal-will-redirect-back-with?token=12345' # need to make sure that the gateway
                                                                # knows this token and will give us 
                                                                # back the details we expect

    last_response.should contain('Order successful')
    last_response.should contain('9.95')
  end

  it 'displays errors if the order completion page is visited with an invalid token'

  it 'handles when a user cancels (redirects the user back to the page they came from)'

end
