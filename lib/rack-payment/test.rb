# Helpers for testing Rack::Payment

require 'ostruct'

module ActiveMerchant #:nodoc:
  module Billing      #:nodoc:

    # ...
    class BogusExpressGateway < BogusGateway

      # override default purchase
      def purchase amount, options
        raise "amount required"  if amount.nil?
        raise "options required" if options.nil? or options.empty?

        formatted_amount = sprintf '%.2f', (amount.to_f / 100.0)

        yml = "--- !ruby/object:ActiveMerchant::Billing::PaypalExpressResponse \nauthorization: 4GN164705L1464005\navs_result: \n code: \n postal_match: \n street_match: \n message: \ncvv_result: \n code: \n message: \nfraud_review: false\nmessage: Success\nparams: \n payment_status: Completed\n tax_amount_currency_id: USD\n correlation_id: 820981d27a38f\n timestamp: \"2010-01-21T04:33:37Z\"\n pending_reason: none\n token: EC-9UM24360U0340274A\n transaction_id: 4GN164705L1464005\n fee_amount_currency_id: USD\n transaction_type: express-checkout\n build: \"1152253\"\n tax_amount: \"0.00\"\n version: \"52.0\"\n receipt_id: \n gross_amount_currency_id: USD\n parent_transaction_id: \n fee_amount: \"0.73\"\n exchange_rate: \n gross_amount: \"#{ formatted_amount }\"\n payment_date: \"2010-01-21T04:33:36Z\"\n ack: Success\n reason_code: none\n payment_type: instant\nsuccess: true\ntest: true\n"

        YAML.load(yml)
      end
    
      def setup_purchase amount, options
        raise "amount required"  if amount.nil?
        raise "options required" if options.nil? or options.empty?
        OpenStruct.new :token => '123'
      end

      def redirect_url_for token
        raise "token required" if token.nil?
        'http://www.some-express-gateway-url/'
      end

      def details_for token
        raise "token required" if token.nil?
        OpenStruct.new :payer_id => '1'
      end

    end

  end
end
