module Rack     #:nodoc:
  class Payment #:nodoc:

    # TODO add usage doco
    #
    # This is meant to be included into a class that 
    # represents a person/whatever who you will be billing.
    module Billable

      def self.included base
        base.send :extend, ClassMethods
      end

      # @return [Rack::Payment::EncryptedCreditCard]
      def credit_card
        @_rack_payment_encrypted_credit_card ||= Rack::Payment::EncryptedCreditCard.new(self)
      end

      # Adds a scheduled payment to the queue of scheduled payments.
      #
      # Assumes that a #scheduled_payments methods is available (as an association).
      #
      # @param [Float] The amount due
      # @param [DateTime] When the payment is due (when it should be processed)
      def schedule_payment! amount, due_at
        scheduled_payments.create :amount => amount, :due_at => due_at
      end

      # Process the given payment.  The completed payment should be returned.
      #
      # If the payment is processed OK, the payment should be deleted from 
      # the queue (scheduled_payments) and added to completed_payments.
      def process_due_payment! payment
        rack_payment = Rack::Payment.instance.payment
        rack_payment.amount      = payment.amount
        rack_payment.credit_card = credit_card # use the encrypted credit card
        rack_payment.purchase :ip => '127.0.0.1'

        completed = completed_payments.create :amount   => payment.amount, 
                                              :due_at   => payment.due_at,
                                              :success  => rack_payment.success?,
                                              :response => rack_payment.response
        # TODO add amount_paid
        payment.destroy
        completed
      end
        
      def future_payments current_time = Time.now
        scheduled_payments.future
      end

      def due_payments current_time = Time.now
        scheduled_payments.due
      end

      module ClassMethods
        
        def future_payments current_time = Time.now
          raise NotImplementedError, 'future_payments has no generic implementation (yet?)'
        end

        def due_payments current_time = Time.now
          raise NotImplementedError, 'due_payments has no generic implementation (yet?)'
        end

        def process_due_payments! current_time = Time.now
          processed_payments = []
          due_payments(current_time).each do |due_payment|
            processed_payments << due_payment.parent.process_due_payment!(due_payment)
          end
          processed_payments.compact
        end

      end

    end

  end
end
