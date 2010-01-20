module Rack     #:nodoc:
  class Payment #:nodoc:

    # ...
    class Request
      extend Forwardable

      def_delegators :payment_instance, :app, :gateway, :express_gateway, :on_success, :built_in_form_path, 
                                        :env_instance_variable, :env_data_variable, :session_variable,
                                        :rack_session_variable, :express_ok_path, :express_cancel_path,
                                        :built_in_form_path
      def_delegators :request, :params

      # raw ENV hash
      attr_accessor :env

      # Rack::Request
      attr_accessor :request

      # Rack::Response that results from calling the Rack application
      attr_accessor :app_response

      attr_accessor :post_came_from_the_built_in_forms

      attr_accessor :payment_instance

      def post_came_from_the_built_in_forms?
        post_came_from_the_built_in_forms == true
      end

      def payment
        env[env_data_variable] ||= Rack::Payment::Data.new
      end

      def session
        env[rack_session_variable][session_variable] ||= {}
      end

      def amount_in_session
        session[:amount]
      end

      def amount_in_session= value
        session[:amount] = value
      end

      # ...
      def initialize env, payment_instance
        @payment_instance = payment_instance

        self.env          = env
        self.request      = Rack::Request.new @env

        raw_rack_response = app.call env
        self.app_response = Rack::Response.new raw_rack_response[2], raw_rack_response[0], raw_rack_response[1]
      end

      # The final rack response.  This "runs" the request.
      def finish
        if app_response.status == 402 # Payment Required

          self.amount_in_session = payment.amount # we need to put this in the session ... i forget why ...

          return process_credit_card if payment.use_express?

          if payment.card_or_address_partially_filled_out?
            return process_credit_card # You've filled stuff out!  Try to process ...
          else
            return credit_card_and_billing_info_response # Payment Required!
          end

        elsif request.path_info == built_in_form_path
          self.post_came_from_the_built_in_forms = true
          return process_credit_card # Try to process the request

        elsif request.path_info == express_ok_path
          return process_express_payment_callback
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

        return setup_express_purchase if payment.use_express?

        # Check for Credit Card errors
        errors = payment.credit_card.errors

        # Try to #authorize (if no errors so far)
        if errors.empty?
          begin
            payment.raw_authorize_response = gateway.authorize payment.amount_in_cents, 
                                                           payment.credit_card.active_merchant_card, 
                                                           :ip => request.ip
            errors << payment.raw_authorize_response.message unless payment.raw_authorize_response.success?
          rescue ActiveMerchant::Billing::Error => error
            payment.raw_authorize_response = OpenStruct.new :success? => false, :message => error.message
            errors << error.message
          end
        end

        # Try to #capture (if no errors so far)
        if errors.empty?
          begin
            payment.raw_capture_response = gateway.capture payment.amount_in_cents, payment.raw_authorize_response.authorization
            errors << payment.raw_capture_response.message unless payment.raw_capture_response.success?
          rescue ActiveMerchant::Billing::Error => error
            payment.raw_capture_response = OpenStruct.new :success? => false, :message => error.message
            errors << payment.raw_capture_response.message
          end
        end

        # RENDER
        if errors.empty?
          render_on_success
        else
          render_on_error errors
        end
      end

      def setup_express_purchase
        # TODO we should get the callback URLs to use from the Rack::Purchase
        #      and they should be overridable

        # TODO go BOOM if the express gateway isn't set!
        response = express_gateway.setup_purchase payment.amount_in_cents, :ip                => request.ip, 
                                                                           :return_url        => express_ok_path,
                                                                           :cancel_return_url => express_cancel_path

        [ 302, {'Location' => express_gateway.redirect_url_for(response.token)}, ['Redirecting to PayPal Express Checkout'] ]
      end

      def render_on_error errors
        if post_came_from_the_built_in_forms?
          # we POSTed from our form, so let's re-render our form
          credit_card_and_billing_info_response errors
        else
          # pass along the errors to the application's custom page, which should be the current URL
          # so we can actually just re-call the same env (should display the form) using a GET
          payment.errors = errors
          new_env = env.clone
          new_env['REQUEST_METHOD'] = 'GET'
          app.call(new_env)
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

        @this    = self
        @errors  = errors
        @params  = params

        html = ERB.new(erb).result(binding)
        
        [ 200, {'Content-Type' => 'text/html'}, html ]
      end

      def process_express_payment_callback
        payment.amount ||= amount_in_session # gets lost because we're coming here directly from PayPal

        details = express_gateway.details_for params['token']

        express_gateway.purchase payment.amount_in_cents, :ip       => request.ip,
                                                          :token    => params['token'],
                                                          :payer_id => details.payer_id

        # should be complete ...
        [ 200, {}, ["Order successful.  You should have been charged #{ payment.amount }" ]]
      end

    end

  end
end
