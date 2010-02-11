module Rack     #:nodoc:
  class Payment #:nodoc:

    # TODO add usage doco
    #
    # This is meant to be included into a class that 
    # represents a person/whatever who you will be billing.
    module Billable

      def credit_card
        @_rack_payment_encrypted_credit_card ||= Rack::Payment::EncryptedCreditCard.new(self)
      end

    end

  end
end
