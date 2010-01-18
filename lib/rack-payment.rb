$LOAD_PATH.unshift File.dirname(__FILE__)

%w( active_merchant rack bigdecimal ).each {|lib| require lib }

require 'rack-payment/payment'
require 'rack-payment/credit_card'
require 'rack-payment/billing_address'
require 'rack-payment/data'
require 'rack-payment/methods'

module Rack #:nodoc:

  class Payment

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

      # puts "#call #{ request.request_method } #{ request.path_info }"

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
