# Simple application
#
# Replies on Rack:Payment to supply a page for filling out 
# credit card / billing information as well as for displaying 
# a confirmation page after a successful purchase
#
# It exposes SimpleApp::gateway for testing
#
class SimpleApp < Sinatra::Base

  class << self; attr_accessor :gateway; end
  @gateway = ActiveMerchant::Billing::BogusGateway.new

  use Rack::Session::Cookie

  use Rack::Payment, gateway

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    %{
      <form action='/' method='post'>
        <input type='text' id='monies' name='monies' />
        <input type='submit' value='Checkout' />
      </form>
     }
  end

  post '/' do
    payment.amount = params[:monies]
    [ 402, {}, ['Payment Required'] ]
  end
end
