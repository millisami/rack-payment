module Rack     #:nodoc:
  class Payment #:nodoc:

    class Data
      attr_accessor :amount, :capture_response, :authorize_response, :credit_card, :billing_address, :errors

      def errors
        @errors ||= []
      end

      def credit_card
        @credit_card ||= CreditCard.new
      end

      def billing_address
        @billing_address ||= BillingAddress.new
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
