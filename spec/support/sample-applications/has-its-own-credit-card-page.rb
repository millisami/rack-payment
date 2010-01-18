class SimpleAppWithOwnCreditCardPage < Sinatra::Base

  class << self; attr_accessor :gateway; end
  @gateway = ActiveMerchant::Billing::BogusGateway.new

  use Rack::Session::Cookie

  use Rack::Payment, gateway

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    html = "<h1>Custom Page</h1>"
    html += "<form action='/' method='post'>"
    html += "<input type='text' id='monies' name='monies' />"
    %w( first_name last_name number cvv expiration_month expiration_year type ).each do |field|
      full_field = "credit_card[#{field}]"
      html += "<input type='text' name='#{full_field}' value='#{ params[full_field] }' />"
    end

    %w( name address1 city state country zip ).each do |field|
      full_field = "address[#{ field }]"
      html += "<input type='text' name='#{full_field}' value='#{ params[full_field] }' />"
    end
    html += "<input type='submit' value='Purchase' />"
    html += "</form>"

    html
  end

  post '/' do
    payment.amount = params[:monies]

    # raise params[:credit_card].inspect
    payment.credit_card.update     params[:credit_card]
    payment.billing_address.update params[:address]

    [ 402, {}, ['Payment Required'] ]
  end
end
