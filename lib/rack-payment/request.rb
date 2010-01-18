module Rack     #:nodoc:
  class Payment #:nodoc:

    # ...
    class Request
      extend Forwardable

      def_delegators :payment_instance, :app, :gateway, :on_success
      def_delegators :request, :params

      # raw ENV hash
      attr_accessor :env

      # Rack::Request
      attr_accessor :request

      # Rack::Response that results from calling the Rack application
      attr_accessor :app_response

      attr_accessor :post_came_from_the_built_in_forms

      def post_came_from_the_built_in_forms?
        post_came_from_the_built_in_forms == true
      end

      def payment_instance
        env['rack.payment']
      end

      def payment
        env['rack.payment.data'] ||= Rack::Payment::Data.new
      end

      def amount_in_session
        env['rack.session']['rack.payment'] ||= {}
        env['rack.session']['rack.payment']['amount']
      end

      def amount_in_session= value
        env['rack.session']['rack.payment'] ||= {}
        env['rack.session']['rack.payment']['amount'] = value
      end

      # ...
      def initialize env
        self.env          = env
        self.request      = Rack::Request.new @env

        raw_rack_response = app.call env
        self.app_response = Rack::Response.new raw_rack_response[2], raw_rack_response[0], raw_rack_response[1]
      end

      # The final rack response.  This "runs" the request.
      def finish
        if app_response.status == 402 # Payment Required

          self.amount_in_session = payment.amount # we need to put this in the session ... i forget why ...

          if payment.card_or_address_partially_filled_out?
            return process_credit_card # You've filled stuff out!  Try to process ...
          else
            return credit_card_and_billing_info_response # Payment Required!
          end

        elsif request.path_info == '/rack-payment-processing'
          self.post_came_from_the_built_in_forms = true
          return process_credit_card # Try to process the request
        end

        app_response.finish # default to returning the application's response
      end

      def process_credit_card
        payment.amount ||= amount_in_session

        # the params *should* be set on the payment data object, but we accept 
        # POST requests too, so we check the POST variables for credit_card 
        # or billing_address fields
        params.each do |field, value|
          if field =~ /^credit_card_(\w+)/
            payment.credit_card.update $1 => value
          elsif field =~ /billing_address_(\w+)/
            payment.billing_address.update $1 => value
          end 
        end

        if payment.credit_card.errors.empty?
          begin
            payment.authorize_response = gateway.authorize payment.amount_in_cents, payment.credit_card.active_merchant_card
          rescue ActiveMerchant::Billing::Error => error
            payment.authorize_response = OpenStruct.new :success? => false, :message => error.message
          end

          if payment.authorize_response.success?

            # TODO handle when capture throws an exception
            payment.capture_response = gateway.capture payment.amount_in_cents, payment.authorize_response.authorization
            render_on_success

          else
            # authorization wasn't successful
            if post_came_from_the_built_in_forms?
              credit_card_and_billing_info_response [payment.authorize_response.message]
            else
              # pass along the errors to the application's custom page, which should be the current URL
              # so we can actually just re-call the same env (should display the form) using a GET
              payment.errors = [payment.authorize_response.message]
              new_env = env.clone
              new_env['REQUEST_METHOD'] = 'GET'
              app.call(new_env)
            end
          end

        else
          # credit card has errors
          credit_card_and_billing_info_response payment.credit_card.errors
        end
      end

      def render_on_success
        if on_success
          # on_success is overriden ... we #call the main application using the on_success path
          new_env = env.clone
          new_env['PATH_INFO']      = on_success
          new_env['REQUEST_METHOD'] = 'GET'
          app.call new_env
        else
          # on_success has not been overriden ... let's just display out own info
          [ 200, {}, ["Order successful.  You should have been charged #{ payment.amount }" ]]
        end
      end

      def credit_card_and_billing_info_response errors = nil
        view = ::File.dirname(__FILE__) + '/views/credit-card-and-billing-info-form.html.erb'
        erb  = ::File.read view

        @errors = errors
        @params = params

        html = ERB.new(erb).result(binding)
        
        [ 200, {'Content-Type' => 'text/html'}, html ]
      end

    end

  end
end
