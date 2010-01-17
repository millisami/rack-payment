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

    class CreditCard
      attr_accessor :active_merchant_card

      def initialize
        @active_merchant_card ||= ActiveMerchant::Billing::CreditCard.new
      end

      def method_missing name, *args, &block
        if active_merchant_card.respond_to?(name)
          active_merchant_card.send(name, *args, &block)
        else
          super
        end
      end

      def partially_filled_out?
        %w( type number verification_value month year first_name last_name ).each do |field|
          return true unless send(field).nil?
        end

        return false
      end

      def update options
        options.each {|key, value| send "#{key}=", value }
      end

      # Aliases

      def cvv()       verification_value         end
      def cvv=(value) verification_value=(value) end

      def expiration_year()       year         end
      def expiration_year=(value) year=(value) end

      def expiration_month()       month         end
      def expiration_month=(value) month=(value) end

      def type
        active_merchant_card.type
      end

    end

    class BillingAddress
      attr_accessor :name, :address1, :city, :state, :zip, :country

      def update options
        options.each {|key, value| send "#{key}=", value }
      end

      def partially_filled_out?
        %w( name address1 city state zip country ).each do |field|
          return true unless send(field).nil?
        end

        return false
      end
    end

    class Data
      attr_accessor :amount, :capture_response, :authorize_response, :credit_card, :billing_address

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

    DEFAULT_OPTIONS = { }

    attr_accessor :app

    attr_accessor :gateway

    attr_accessor :on_success

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

        payment = env['rack.payment.data']

        # check for payment.amount ... should blow up if not set
        env['rack.session']['rack.payment'] ||= {}
        env['rack.session']['rack.payment']['amount'] = payment.amount

        if payment.card_or_address_partially_filled_out?

          # You've filled stuff out!  Try to process ...
          return process_credit_card(env)
        else

          # Payment Required!
          return credit_card_and_billing_info_response env
        end

      elsif request.path_info == '/rack-payment-processing'

        # Try to process the request
        return process_credit_card(env)

      end

      app_response.finish
    end

    def process_credit_card env
      env['rack.payment.data'] ||= Rack::Payment::Data.new
      payment = env['rack.payment.data']
      payment.amount ||= env['rack.session']['rack.payment']['amount']

      unless payment.card_or_address_partially_filled_out?
        Rack::Request.new(env).params.each do |field, value|
          if field =~ /^credit_card_(\w+)/
            payment.credit_card.update $1 => value
          elsif field =~ /billing_address_(\w+)/
            payment.billing_address.update $1 => value
          end 
        end
      end

      # TODO move errors into CreditCard and BillingAddress objects
      errors   = []
      required = %w( number first_name last_name )
      required.each do |field|
        value = payment.credit_card.send(field)
        errors << "#{ field } is required" if value.nil? or value.empty?
      end

      if errors.empty?

        # All looks good ... try to process it!
        card = payment.credit_card.active_merchant_card

        payment.authorize_response = gateway.authorize payment.amount_in_cents, card

        if payment.authorize_response.success?

          payment.capture_response = gateway.capture payment.amount_in_cents, payment.authorize_response.authorization

          if on_success
            new_env = env.clone
            new_env['PATH_INFO'] = on_success
            new_env['REQUEST_METHOD'] = 'GET'

            @app.call new_env
          else
            [ 200, {}, ["Order successful.  You should have been charged #{ payment.amount }" ]]
          end

        else
          credit_card_and_billing_info_response env, [payment.authorize_response.message]
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
