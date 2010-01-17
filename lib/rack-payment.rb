require 'active_merchant'
require 'rack'
require 'bigdecimal'

module Rack #:nodoc:

  class Payment

    module Methods

      def payment
        payment_request_env['rack.payment.data'] ||= Rack::Payment::Data.new
      end

      # [Internal] this method returns the Rack 'env' for the current request.
      #
      # This looks for #env or #request.env by default.  If these don't return 
      # something, then we raise an exception and you should override this method 
      # so it returns the Rack env that we need.
      #
      # TODO lots of middleware might use a method like this ... refactor out?
      def payment_request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) and request.respond_to?(:env)
          request.env
        else
          raise "Couldn't find 'env' ... please override #payment_request_env"
        end
      end

    end

    class Data
      attr_accessor :amount

      def amount= value
        @amount = BigDecimal(value.to_s)
      end
    end

    DEFAULT_OPTIONS = { }

    attr_accessor :app

    attr_accessor :gateway

    # @param [#call] Rack application
    # @param [#purchase] {ActiveMerchant::Billing::Gateway}
    def initialize rack_application, active_merchant_gateway, options = nil
      raise ArgumentError, 'You must pass a valid Rack application' unless rack_application.respond_to?(:call)
      raise ArgumentError, 'You must pass a valid Gateway'          unless active_merchant_gateway.respond_to?(:purchase)

      @app     = rack_application
      @gateway = active_merchant_gateway

      DEFAULT_OPTIONS.each {|name, value| send "#{name}=", value }
      options.each         {|name, value| send "#{name}=", value } if options
    end

    # @param [Hash] The Rack Request environment variables
    def call env
      env['rack.payment'] = self # make this instance of Rack::Payment available

      request = Rack::Request.new(env)

      puts "#call #{ request.request_method } #{ request.path_info }"

      raw_response = @app.call env
      app_response = Rack::Response.new raw_response[2], raw_response[0], raw_response[1]

      if app_response.status == 402

        # check for payment.amount ... should blow up if not set
        env['rack.session']['rack.payment'] ||= {}
        env['rack.session']['rack.payment']['amount'] = env['rack.payment.data'].amount

        # Payment Required!
        return credit_card_and_billing_info_response env

      elsif request.path_info == '/rack-payment-processing'

        # Try to process the request
        return process_credit_card(env)

      end

      app_response.finish
    end

    def process_credit_card env

      errors   = []
      required = %w( credit_card_number credit_card_first_name credit_card_last_name )
      params   = Rack::Request.new(env).params
      required.each do |field|
        value = params[field]
        errors << "#{ field } is required" if value.nil? or value.empty?
      end
      
      amount = env['rack.session']['rack.payment']['amount'] # from session (only secure way)
      amount_in_cents = (amount * 100).to_i

      if errors.empty?

        # All looks good ... try to process it!
        card = ActiveMerchant::Billing::CreditCard.new(
            :type               => params['credit_card_type'],
            :number             => params['credit_card_number'],
            :verification_value => params['credit_card_cvv'],
            :month              => params['credit_card_expiration_month'],
            :year               => params['credit_card_expiration_year'],
            :first_name         => params['credit_card_first_name'],
            :last_name          => params['credit_card_last_name']
        )

        authorize_response = gateway.authorize amount_in_cents, card

        if authorize_response.success?
          [ 200, {}, "Order successful.  You should have been charged #{ amount }" ]
        else
          credit_card_and_billing_info_response env, [response.message]
        end

      else
        credit_card_and_billing_info_response env, errors
      end
    end

    def credit_card_and_billing_info_response env, errors = nil
      html = ''

      params = Rack::Request.new(env).params

      if errors and not errors.empty?
        html += '<p>' + errors.join(', ') + '</p>'
      end

      html += "<form action='/rack-payment-processing' method='post'>"

      %w( first_name last_name number cvv expiration_month expiration_year type ).each do |field|
        full_field = "credit_card_#{field}"
        html += "<input type='text' name='#{full_field}' value='#{ params[full_field] }' />"
      end

      %w( name address1 city state country zip ).each do |field|
        full_field = "billing_address_#{ field }"
        html += "<input type='text' name='#{full_field}' value='#{ params[full_field] }' />"
      end

      html += "<input type='submit' value='Purchase' />"
      html += "</form>"
      
      [ 200, {'Content-Type' => 'text/html'}, html ]
    end

  end

end
