module Rack     #:nodoc:
  class Payment #:nodoc:

    # When you call {Rack::Payment#call}, a new {Rack::Payment::Request} instance 
    # gets created and it does the actual logic to figure out what to do.
    #
    # The {#finish} method "executes" this class (it figures out what to do).
    #
    class Request
      extend Forwardable

      def_delegators :payment_instance, :app, :gateway, :express_gateway, :built_in_form_path, 
                                        :env_instance_variable, :env_helper_variable, :session_variable,
                                        :rack_session_variable, :express_ok_path, :express_cancel_path
      
      def_delegators :request, :params

      def_delegators :payment, :errors, :credit_card, :billing_address

      # TODO test these!!!
      def express_ok_url
        ::File.join request.url.sub(request.path_info, ''), express_ok_path
      end
      def express_cancel_url
        ::File.join request.url.sub(request.path_info, ''), express_cancel_path
      end

      # @return [Hash] Raw Rack env Hash
      attr_accessor :env

      # An instance of Rack::Request that wraps our {#env}.
      # It makes it much easier to access the params, path, method, etc.
      # @return Rack::Request
      attr_accessor :request

      # Rack::Response that results from calling the actual Rack application.
      # [Rack::Response]
      attr_accessor :app_response

      # Whether or not this request's POST came from our built in forms.
      # 
      #  * If true, we think the POST came from our form.
      #  * If false, we think the POST came from a user's custom form.
      #
      # @return [true, false]
      attr_accessor :post_came_from_the_built_in_forms

      # The instance of {Rack::Payment} that this Request is for
      # @return [Rack::Payment]
      attr_accessor :payment_instance

      def post_came_from_the_built_in_forms?
        post_came_from_the_built_in_forms == true
      end

      def payment
        env[env_helper_variable] ||= Rack::Payment::Helper.new(payment_instance)
      end

      def session
        raise "Rack env['#{rack_session_variable}'] is nil.  Has a Rack::Session middleware be enabled?" if env[rack_session_variable].nil?
        env[rack_session_variable][session_variable] ||= {}
      end

      def amount_in_session
        session[:amount]
      end

      def amount_in_session= value
        session[:amount] = value
      end

      # Instantiates a {Rack::Payment::Request} object which basically wraps a 
      # single request and handles all of the logic to determine what to do.
      #
      # Calling {#finish} will return the actual Rack response
      #
      # @param [Hash] The Rack Request environment variables
      # @param [Rack::Payment] The instance of Rack::Payment handling this request
      def initialize env, payment_instance
        @payment_instance = payment_instance

        self.env          = env
        self.request      = Rack::Request.new @env

        raw_rack_response = app.call env
        self.app_response = Rack::Response.new raw_rack_response[2], raw_rack_response[0], raw_rack_response[1]
      end

      # Generates and returns the final rack response.
      #
      # This "runs" the request.  It's the main logic in {Rack::Payment}!
      #
      # @return [Array] A Rack response, eg. `[200, {}, ["Hello World"]]`
      def finish
        update_credit_card_and_billing_address_from_params

        # The application returned a 402 ('Payment Required')
        if app_response.status == 402
          self.amount_in_session = payment.amount
          
          return setup_express_purchase if payment.use_express?
          
          if payment.card_or_address_partially_filled_out?
            return process_credit_card
          else
            return credit_card_and_billing_info_response
          end

        # The requested path matches our built-in form
        elsif request.path_info == built_in_form_path
          self.post_came_from_the_built_in_forms = true
          return process_credit_card 

        # The requested path matches our callback for express payments
        elsif request.path_info == express_ok_path
          return process_express_payment_callback
        end

        # If we haven't returned anything, there was no reason for the 
        # middleware to handle this request so we return the real 
        # application's response.
        app_response.finish
      end

      # If the params include fields that start with credit_card_ or 
      # the params have a hash of credit card variables, we use them 
      # to update our credit card information.
      #
      # We do the same with the billing address.
      def update_credit_card_and_billing_address_from_params
        # The params *should* be set on the payment data object, but we accept 
        # POST requests too, so we check the POST variables for credit_card 
        # or billing_address fields
        #
        # TODO deprecate this in favor of the more conventional credit_card[number] syntax?
        #
        params.each do |field, value|
          if field =~ /^credit_card_(\w+)/
            payment.credit_card.update $1 => value
          elsif field =~ /billing_address_(\w+)/
            payment.billing_address.update $1 => value
          end 
        end

        # We also accept credit_card[number] style params, which Rack supports
        if params['credit_card'] and params['credit_card'].respond_to?(:each)
          payment.credit_card.update params['credit_card']
        end
        if params['billing_address'] and params['billing_address'].respond_to?(:each)
          payment.billing_address.update params['billing_address']
        end
      end

      # Gets parameters, attempts an #authorize call, attempts a #capture call, 
      # and renders the results.
      def process_credit_card
        payment.amount ||= amount_in_session

        update_credit_card_and_billing_address_from_params

        # Purchase!
        if payment.purchase(:ip => request.ip)
          render_on_success
        else
          render_on_error payment.errors
        end
      end

      def setup_express_purchase
        # TODO we should get the callback URLs to use from the Rack::Purchase
        #      and they should be overridable

        # TODO go BOOM if the express gateway isn't set!
      
        # TODO catch exceptions

        # TODO catch ! success?
        response = express_gateway.setup_purchase payment.amount_in_cents, :ip                => request.ip, 
                                                                           :return_url        => express_ok_url,
                                                                           :cancel_return_url => express_cancel_url

        [ 302, {'Location' => express_gateway.redirect_url_for(response.token)}, ['Redirecting to PayPal Express Checkout'] ]
      end

      def render_on_error errors
        if post_came_from_the_built_in_forms?
          # we POSTed from our form, so let's re-render our form
          credit_card_and_billing_info_response
        else
          # pass along the errors to the application's custom page, which should be the current URL
          # so we can actually just re-call the same env (should display the form) using a GET
          payment.errors = errors
          new_env = env.clone
          cleanup_env_for_rails(new_env)
          new_env['REQUEST_METHOD'] = 'GET'

          if request.path_info == express_ok_path # if express, we render on_success
            new_env['PATH_INFO'] = (payment.on_success || payment_instance.on_success)
          elsif payment.on_error
            new_env['PATH_INFO'] = payment.on_error # Specific to this request
          elsif payment_instance.on_error
            new_env['PATH_INFO'] = payment_instance.on_error # Global
          end

          app.call(new_env)
        end
      end

      # Rails keeps track of its own Request/Response.
      #
      # If we're using Rails, we need to delete these variables 
      # to trick Rails into thinking that this is a new request.
      #
      # Kind of icky!
      def cleanup_env_for_rails new_env
        new_env.delete 'action_controller.rescue.request'
        new_env.delete 'action_controller.rescue.response'
        new_env.delete 'REQUEST_URI'
      end

      def render_on_success
        on_success = (payment.on_success || payment_instance.on_success)

        if on_success
          # on_success is overriden ... we #call the main application using the on_success path
          new_env = env.clone
          cleanup_env_for_rails(new_env)
          new_env['PATH_INFO']      = on_success
          new_env['REQUEST_METHOD'] = 'GET'
          app.call new_env
        else
          # on_success has not been overriden ... let's just display out own info
          [ 200, {'Content-Type' => 'text/html'}, ["Order successful.  You should have been charged #{ payment.amount }" ]]
        end
      end

      def credit_card_and_billing_info_response
        css_file  = ::File.dirname(__FILE__) + '/views/credit-card-and-billing-info-form.css'
        form_html = payment.form :post_to => built_in_form_path, :inline_css => ::File.read(css_file)
        layout    = ::File.dirname(__FILE__) + '/views/layout.html'
        html      = ::File.read(layout)
        html      = html.sub 'CONTENT', form_html

        [ 200, {'Content-Type' => 'text/html'}, [html] ]
      end

      def process_express_payment_callback
        payment.amount ||= amount_in_session # gets lost because we're coming here directly from PayPal

        details = express_gateway.details_for params['token']

        payment.raw_express_response = express_gateway.purchase payment.amount_in_cents, :ip       => request.ip,
                                                                                         :token    => params['token'],
                                                                                         :payer_id => details.payer_id

        render_on_success
      end

    end

  end
end
