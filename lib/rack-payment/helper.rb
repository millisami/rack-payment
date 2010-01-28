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

      def_delegators :rack_payment, :gateway, :built_in_form_path, :logger, :logger=

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

      # Move these out into a module or something?

      def log_purchase_start transaction_id, options
        logger.debug { "[#{transaction_id}] #purchase(#{options.inspect}) for amount_in_cents: #{ amount_in_cents.inspect }" } if logger
      end

      def log_invalid_credit_card transaction_id
        logger.warn { "[#{transaction_id}] invalid credit card: #{ errors.inspect }" } if logger
      end

      def log_authorize_successful transaction_id, options
        logger.debug { "[#{transaction_id}] #authorize(#{amount_in_cents.inspect}, <CreditCard for #{ credit_card.full_name.inspect }>, :ip => #{ options[:ip].inspect }) was successful" } if logger
      end

      def log_authorize_unsuccessful transaction_id, options
        logger.debug { "[#{transaction_id}] #authorize(#{amount_in_cents.inspect}, <CreditCard for #{ credit_card.full_name.inspect }>, :ip => #{ options[:ip].inspect }) was unsuccessful: #{ errors.inspect }" } if logger
      end

      def log_capture_successful transaction_id
          logger.debug { "[#{transaction_id}] #capture(#{amount_in_cents}, #{raw_authorize_response.authorization.inspect}) was successful" } if logger
      end

      def log_capture_unsuccessful transaction_id
          logger.debug { "[#{transaction_id}] #capture(#{amount_in_cents}, #{raw_authorize_response.authorization.inspect}) was unsuccessful: #{ errors.inspect }" } if logger
      end

      # Fires off a purchase!
      #
      # This resets #errors and #response
      #
      def purchase options
        transaction_id = DateTime.now.strftime('%Y-%m-%d %H:%M:%S %L') # %L to include milliseconds
        log_purchase_start(transaction_id, options)

        raise "#amount_in_cents must be greater than 0" unless amount_in_cents.to_i > 0
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
            self.raw_authorize_response = gateway.authorize amount_in_cents, credit_card.active_merchant_card, :ip => options[:ip], :billing_address => billing_address.active_merchant_hash
            unless raw_authorize_response.success?
              errors << raw_authorize_response.message
              log_authorize_unsuccessful(transaction_id, options)
            end
          rescue ActiveMerchant::Billing::Error => error
            self.raw_authorize_response = OpenStruct.new :success? => false, :message => error.message, :authorization => nil
            errors << error.message
            log_authorize_unsuccessful(transaction_id, options)
          end
        else
          log_invalid_credit_card(transaction_id)
        end

        # Try to #capture (if no errors so far)
        if errors.empty?
          log_authorize_successful(transaction_id, options)
          begin
            self.raw_capture_response = gateway.capture amount_in_cents, raw_authorize_response.authorization
            unless raw_capture_response.success?
              errors << raw_capture_response.message
              log_capture_unsuccessful(transaction_id)
            end
          rescue ActiveMerchant::Billing::Error => error
            self.raw_capture_response = OpenStruct.new :success? => false, :message => error.message
            errors << raw_capture_response.message
            log_capture_unsuccessful(transaction_id)
          end
        end

        log_capture_successful(transaction_id) if errors.empty?

        return errors.empty?
      end

      # Returns the HTML for the built in form
      #
      # By default, the form will POST to the current URL (action='')
      #
      # You can pass a different URL for the form action
      def form post_to = '', options = nil
        view = ::File.dirname(__FILE__) + '/views/credit-card-and-billing-info-form.html.erb'
        erb  = ::File.read view
        html = ''

        if options and options[:inline_css]
          html << "<style type='text/css'>\n#{ options[:inline_css] }\n</style>"
        end

        html << ERB.new(erb).result(binding)
      end

      def options_for_expiration_month selected = nil
        %w( 01 02 03 04 05 06 07 08 09 10 11 12 ).map { |month|
          if selected and selected.to_s == month.to_s
            "<option selected='selected'>#{ month }</option>"
          else
            "<option>#{ month }</option>"
          end
        }.join
      end

      def options_for_expiration_year selected = nil
        (Date.today.year..(Date.today.year + 15)).map { |year|
          if selected and selected.to_s == year.to_s
            "<option selected='selected'>#{ year }</option>"
          else
            "<option>#{ year }</option>"
          end
        }.join
      end

      def options_for_credit_card_type selected = nil
        [ ['visa', 'Visa'], ['master', 'MasterCard'], ['american_express', 'American Express'], 
          ['discover', 'Discover'] ].map { |value, name|
        
          if selected and selected.to_s == value.to_s
            "<option value='#{ value }' selected='selected'>#{ name }</option>"
          else
            "<option value='#{ value }'>#{ name }</option>"
          end
        }.join
      end
    end

  end
end
