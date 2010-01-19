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
        nil
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
