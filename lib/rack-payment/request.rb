module Rack     #:nodoc:
  class Payment #:nodoc:

    # ...
    class Request
      extend Forwardable

      def_delegators :payment_instance, :app, :gateway, :on_success

      # raw ENV hash
      attr_accessor :env

      # Rack::Request
      attr_accessor :req

      def payment_instance
        env['rack.payment']
      end

      def initialize env
        self.env = env
        self.req = Rack::Request.new @env
      end

      # the final rack response
      def finish
        request = Rack::Request.new(env)

        raw_response = app.call env
        app_response = Rack::Response.new raw_response[2], raw_response[0], raw_response[1]

        if app_response.status == 402

          payment = env['rack.payment.data'] # data put into ENV

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
        payment.amount ||= env['rack.session']['rack.payment']['amount'] # sometimes we get the amount from the session ...

        unless payment.card_or_address_partially_filled_out?
          Rack::Request.new(env).params.each do |field, value|
            if field =~ /^credit_card_(\w+)/
              payment.credit_card.update $1 => value
            elsif field =~ /billing_address_(\w+)/
              payment.billing_address.update $1 => value
            end 
          end
        end

        if payment.credit_card.errors.empty?
          payment.authorize_response = gateway.authorize payment.amount_in_cents, payment.credit_card.active_merchant_card

          if payment.authorize_response.success?
            payment.capture_response = gateway.capture payment.amount_in_cents, payment.authorize_response.authorization

            if on_success
              new_env = env.clone
              new_env['PATH_INFO'] = on_success
              new_env['REQUEST_METHOD'] = 'GET'

              app.call new_env
            else
              [ 200, {}, ["Order successful.  You should have been charged #{ payment.amount }" ]]
            end

          else
            credit_card_and_billing_info_response env, [payment.authorize_response.message]
          end

        else
          credit_card_and_billing_info_response env, payment.credit_card.errors
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
end
