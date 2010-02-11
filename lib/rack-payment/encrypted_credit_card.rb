module Rack     #:nodoc:
  class Payment #:nodoc:

    # When you include {Rack::Payment::Billable}, 
    # the #credit_card method you get returns an 
    # instance of {EncryptedCreditCard}.
    class EncryptedCreditCard < CreditCard

      # The class instance (usually a DataMapper/ActiveRecord model) 
      # that this {EncryptedCreditCard} is wrapping.
      attr_reader :instance

      # The instance of {Rack::Payment} that this credit card is associated with.
      # This is important because {Rack::Payment} has your configuration options 
      # and it's actually responsible for the encryption via {Rack::Payment#encrypt} 
      # and {Rack::Payment#decrypt} using {Rack::Payment#encryption_key}.
      attr_accessor :rack_payment_instance

      def initialize instance, rack_payment_instance = Rack::Payment.instance
        @instance              = instance
        @rack_payment_instance = rack_payment_instance
        check_for_required_fields!
      end

      def check_for_required_fields!
        # TODO write a spec fool!
      end

      REQUIRED.each do |field|
        
        define_method(field) do
          value = instance.send("credit_card_#{field}")
          rack_payment_instance.decrypt(value) if value
        end
        
        define_method("#{field}=") do |value|
          instance.send "credit_card_#{field}=", rack_payment_instance.encrypt(value)
        end

      end

    end

  end
end
