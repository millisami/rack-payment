module Rack     #:nodoc:
  class Payment #:nodoc:

    class Data
      extend Forwardable

      def_delegators :response, :raw_authorize_response, :raw_capture_response, :amount_paid,
                      :raw_authorize_response=, :raw_capture_response=

      attr_accessor :amount, :credit_card, :billing_address, :errors, :use_express, :response

      def use_express
        @use_express.nil? ? false : @use_express # default to false
      end

      def use_express?
        self.use_express == true
      end

      def use_express!
        self.use_express = true 
      end

      def errors
        @errors ||= []
      end

      def credit_card
        @credit_card ||= CreditCard.new
      end

      def billing_address
        @billing_address ||= BillingAddress.new
      end

      def response
        @response ||= Response.new
      end

      def amount= value
        @amount = BigDecimal(value.to_s)
      end

      def amount_in_cents
        (amount * 100).to_i if amount
      end

      def card_or_address_partially_filled_out?
        credit_card.partially_filled_out? or billing_address.partially_filled_out?
      end
    end

  end
end
