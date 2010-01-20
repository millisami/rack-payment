module Rack #:nodoc:

  # Rack::Payment is a Rack middleware for adding simple payment to your applications.
  #
  #   use Rack::Payment, :gateway => 'paypal', :login => '...', :password => '...'
  #
  # Rack::Payment wraps {ActiveMerchant} so any gateway that {ActiveMerchant} supports 
  # *should* be usable in Rack::Payment.
  #
  # When you `#call` this middleware, a new {Rack::Payment::Request} instance 
  # gets created and it does the actual logic to figure out what to do.
  #
  class Payment

    # These are the default values that we use to set the Rack::Payment attributes.
    #
    # These can all be overriden by passing the attribute name and new value to 
    # the Rack::Payment constructor:
    #
    #   use Rack::Payment, :on_success => '/my-custom-page'
    #
    DEFAULT_OPTIONS = {
      :on_success            => nil,
      :built_in_form_path    => '/rack.payment/process',
      :express_ok_path       => '/rack.payment/express.callback/ok',
      :express_cancel_path   => '/rack.payment/express.callback/cancel',
      :env_instance_variable => 'rack.payment',
      :env_data_variable     => 'rack.payment.data',
      :session_variable      => 'rack.payment',
      :rack_session_variable => 'rack.session'
    }

    # The {Rack} application that this middleware was instantiated with
    # @return [#call]
    attr_accessor :app

    # When a payment is successful, we redirect to this path, if set.
    # If this is `nil`, we display our own confirmation page.
    # @return [String, nil] (nil)
    attr_accessor :on_success

    # This is the path that the built-in form POSTs to when submitting 
    # Credit Card data.  This is only used if you use the built_in_form.
    # See {#use_built_in_form} to enable/disable using the default form
    # @return [String]
    attr_accessor :built_in_form_path

    # TODO implement!  NOT IMPLEMENTED YET
    attr_accessor :use_built_in_form

    # This is the path that we have express gateways (Paypal Express) 
    # redirect to, after a purchase has been made.
    # @return [String]
    attr_accessor :express_ok_path

    # This is the path that we have express gateways (Paypal Express) 
    # redirect to if the user cancels their purchase.
    # @return [String]
    attr_accessor :express_cancel_path

    # The name of the Rack env variable to use to access the instance 
    # of Rack::Payment that your application is using as middleware.
    # @return [String]
    attr_accessor :env_instance_variable

    # The name of the Rack env variable to use to access data about 
    # the purchase being made.  Getting this out of the Rack env 
    # gives you a {Rack::Payment::Data} object.
    # @return [String]
    attr_accessor :env_data_variable

    # The name of the variable we put into the Rack::Session 
    # to store anything that {Rack::Payment} needs to keep track 
    # of between requests, eg. the amount that the user is trying 
    # to spend.
    # @return [String]
    attr_accessor :session_variable

    # The name of the Rack env variable used for the Rack::Session, 
    # eg. `rack.session` (the default for Rack::Session::Cookie)
    # @return [String]
    attr_accessor :rack_session_variable

    # The name of a type of ActiveMerchant::Billing::Gateway that we 
    # want to use, eg. 'paypal'.  We use this to get the actual 
    # ActiveMerchant::Billing::Gateway class, eg. ActiveMerchant::Billing::Paypal
    # @return [String]
    attr_accessor :gateway_type

    # The options that are passed to {Rack::Payment} when you include it as a 
    # middleware, minus the options that {Rack::Payment} uses.
    #
    # For example, if you instantiate a {Rack::Payment} middleware with Paypal, 
    # this will probably include :login, :password, and :signature
    # @return [Hash]
    attr_accessor :gateway_options

    # Uses the #gateway_options to instantiate a [paypal] express gateway
    #
    # If your main gateway is a PaypayGateway, we'll make a PaypalExpressGateway
    # If your main gateway is a BogusGateway, we'll make a BogusExpressGateway
    #
    # For any gateway, we'll try to make a *ExpressGateway
    #
    # This ONLY works for classes underneath ActiveMerchant::Billing
    #
    # @return [ActiveMerchant::Billing::Gateway]
    attr_accessor :express_gateway

    def express_gateway
      @express_gateway ||= ActiveMerchant::Billing::Base.gateway(express_gateway_type).new(gateway_options)
    end

    # The name of the gateway to use for an express gateway.
    #
    # If our {#gateway} is a ActiveMerchant::Billing::PaypalGateway, 
    # this will return `paypal_express`
    #
    # Uses the class of #gateway to determine.
    #
    # @return [String]
    def express_gateway_type
      gateway.class.to_s.split('::').last.sub(/(\w+)Gateway$/, '\1_express')
    end

    # The actual instance of ActiveMerchant::Billing::Gateway object to use.
    # Uses the #gateway_type and #gateway_options to instantiate a gateway.
    # @return [ActiveMerchant::Billing::Gateway]
    attr_accessor :gateway

    def gateway
      unless @gateway
        begin
          @gateway = ActiveMerchant::Billing::Base.gateway(gateway_type.to_s).new(gateway_options)
        rescue NameError
          # do nothing, @gateway should be nil because the gateway_type was invalid
        end
      end
      @gateway
    end

    # @overload initialize(rack_application)
    #   Not yet implemented.  This will search for a YML file or ENV variable to set gateway_options.
    #   @param [#call] The Rack application for this middleware
    #
    # @overload initialize(rack_application, gateway_options)
    #   Accepts a Hash of options where the :gateway option is used as the {#gateway_type}
    #   @param [#call] The Rack application for this middleware
    #   @param [Hash] Options for the gateway.  These are passed straight to the gateway initializer.
    #
    # @overload initialize(rack_application, gateway_type, gateway_options)
    #   Accepts a Rack application, a type of gateway to use, and a hash of options for the gateway.
    #   @param [#call] The Rack application for this middleware
    #   @param [String] The type of gateway to use, eg. 'paypal'
    #   @param [Hash] Options for the gateway.  These are passed straight to the gateway initializer.
    def initialize rack_application, gateway_type, gateway_options = nil
      @app             = rack_application

      if gateway_options.nil? and gateway_type.is_a?(Hash)
        @gateway_options = gateway_type
        @gateway_type    = @gateway_options['gateway'] || @gateway_options[:gateway]
      else
        @gateway_options = gateway_options
        @gateway_type    = gateway_type
      end

      raise ArgumentError, 'You must pass a valid Rack application' unless rack_application.respond_to?(:call)
      raise ArgumentError, 'You must pass a valid Gateway'          unless gateway.is_a?(ActiveMerchant::Billing::Gateway)

      DEFAULT_OPTIONS.each {|name, value| send "#{name}=", value }
      DEFAULT_OPTIONS.keys.each {|key| send "#{key}=", @gateway_options[key] if @gateway_options[key] } if @gateway_options
    end

    # The main Rack #call method required by every Rack application / middleware.
    # @param [Hash] The Rack Request environment variables
    def call env
      env[env_instance_variable] ||= self   # make this instance available
      return Request.new(env, self).finish  # a Request object actually returns the response
    end

  end
end
