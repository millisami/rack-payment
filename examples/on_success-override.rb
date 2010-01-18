# 
class SimpleAppWithOnSuccessOverridden < Sinatra::Base

  class << self; attr_accessor :gateway; end
  @gateway = ActiveMerchant::Billing::BogusGateway.new

  use Rack::Session::Cookie

  use Rack::Payment, gateway, :on_success => '/custom_success_page'

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

  get '/custom_success_page' do
    "w00t!  Success!  You should have been charged #{ payment.amount } (#{ payment.amount_in_cents }).  " + 
    "Raw capture response: #{ payment.capture_response.inspect }.  " + 
    "Raw authoriziation request: #{ payment.authorize_response.inspect }"
  end
end
