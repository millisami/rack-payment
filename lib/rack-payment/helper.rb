module Rack     #:nodoc:
  class Payment #:nodoc:

    # When you include {Rack::Payment::Methods} into your application, you 
    # get a {#payment} method/object which gives you an instance of {Rack::Payment::Helper}
    #
    # {Rack::Payment::Helper} is the main API for working with {Rack::Payment}.  You use it to:
    # 
    #  * Set the {#amount} you want to charge someone
    #  * Spit out the HTML for a credit card / billing information {#form} into your own application
    #  * Set the {#credit_card} and {#billing_address} to be used when processing the payment
    #  * Get {#errors} if something didn't work
    #  * Get the {#response} from your billing gateway after charging (or attempting to charge) someone
    #  * Get the URL to the image for a {#paypal_express_button}
    #
    class Helper
      extend Forwardable

      def_delegators :response, :amount_paid, :success?,
                                :raw_authorize_response, :raw_authorize_response=,
                                :raw_capture_response,   :raw_capture_response=, 
                                :raw_express_response,   :raw_express_response=

      def_delegators :rack_payment, :gateway

      attr_accessor :rack_payment, :amount, :credit_card, :billing_address, :errors, :use_express, :response

      # @param [Rack::Payment]
      def initialize rack_payment
        @rack_payment = rack_payment
      end

      def cc
        credit_card
      end

      def use_express
        @use_express.nil? ? false : @use_express # default to false
      end

      def use_express?
        self.use_express == true
      end

      def use_express!
        self.use_express = true 
      end

      # helper for getting the src of the express checkout image
      def paypal_express_button
        'https://www.paypal.com/en_US/i/btn/btn_xpressCheckout.gif'
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

      # The same as {#purchase} but it raises an exception on error.
      def purchase! options
        if response = purchase(options)
          true
        else
          raise "Purchase failed.  #{ errors.join(', ') }"
        end
      end

      # Fires off a purchase!
      #
      # This resets #errors and #response
      #
      def purchase options
        raise ArgumentError, "The :ip option is required when calling #purchase" unless options and options[:ip]

        # Check for Credit Card errors
        self.response = Response.new
        self.errors   = credit_card.errors # start off with any errors from the credit_card

        # Try to #authorize (if no errors so far)
        if errors.empty?
          begin
            # TODO should pass :billing_address, if the billing address isn't empty.
            #      fields: name, address1, city, state, country, zip.
            #      Some gateways (eg. PayPal Pro) require a billing_address!
            self.raw_authorize_response = gateway.authorize amount_in_cents, credit_card.active_merchant_card, :ip => options[:ip]
            errors << raw_authorize_response.message unless raw_authorize_response.success?
          rescue ActiveMerchant::Billing::Error => error
            self.raw_authorize_response = OpenStruct.new :success? => false, :message => error.message
            errors << error.message
          end
        end

        # Try to #capture (if no errors so far)
        if errors.empty?
          begin
            self.raw_capture_response = gateway.capture amount_in_cents, raw_authorize_response.authorization
            errors << raw_capture_response.message unless raw_capture_response.success?
          rescue ActiveMerchant::Billing::Error => error
            self.raw_capture_response = OpenStruct.new :success? => false, :message => error.message
            errors << raw_capture_response.message
          end
        end

        return errors.empty?
      end
    end

  end
end
