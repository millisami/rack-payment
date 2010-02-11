module Rack     #:nodoc:
  class Payment #:nodoc:

    # TODO add usage doco
    #
    # This is meant to be included into a class that 
    # represents a person/whatever who you will be billing.
    module Billable

      # @return [Rack::Payment::EncryptedCreditCard]
      def credit_card
        @_rack_payment_encrypted_credit_card ||= Rack::Payment::EncryptedCreditCard.new(self)
      end

      def schedule_payment! amount, charge_at
        scheduled_payments.create :amount => amount, :charge_at => charge_at
      end

    end

  end
end
