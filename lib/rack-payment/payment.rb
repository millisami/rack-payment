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

    # Default file names that we used to look for yml configuration.
    # You can change {Rack::Payment::yml_file_names} to override.
    YML_FILE_NAMES = %w( .rack-payment.yml rack-payment.yml config/rack-payment.yml 
                         ../config/rack-payment payment.yml ../payment.yml config/payment.yml )

    class << self

      # A string of file names that we use to look for options, 
      # if options are not passes to the Rack::Payment constructor.
      #
      # @return [Array(String)]
      attr_accessor :yml_file_names

      # A standard logger.  Defaults to nil.  We assume that this has 
      # methods like #info that accept a String or a block.
      #
      # If this is set, new instances of Rack::Payment will use this logger by default.
      #
      # @return [Logger]
      attr_accessor :logger
    end

    @yml_file_names = YML_FILE_NAMES

    # These are the default values that we use to set the Rack::Payment attributes.
    #
    # These can all be overriden by passing the attribute name and new value to 
    # the Rack::Payment constructor:
    #
    #   use Rack::Payment, :on_success => '/my-custom-page'
    #
    DEFAULT_OPTIONS = {
      'on_success'            => nil,
      'on_error'              => nil,
      'built_in_form_path'    => '/rack.payment/process',
      'express_ok_path'       => '/rack.payment/express.callback/ok',
      'express_cancel_path'   => '/rack.payment/express.callback/cancel',
      'env_instance_variable' => 'rack.payment',
      'env_helper_variable'   => 'rack.payment.helper',
      'session_variable'      => 'rack.payment',
      'rack_session_variable' => 'rack.session'
    }

    # The {Rack} application that this middleware was instantiated with
    # @return [#call]
    attr_accessor :app

    # A standard logger.  Defaults to nil.  We assume that this has 
    # methods like #info that accept a String or a block
    # @return [Logger]
    attr_accessor :logger

    def logger #:nodoc:
      @logger ||= Rack::Payment.logger
    end

    # When a payment is successful, we render this path, if set.
    # If this is `nil`, we display our own confirmation page.
    # @return [String, nil] (nil)
    attr_accessor :on_success

    # When a payment is unsuccessful, we render this path, if set.
    # If this is `nil`, we render the URL that the POST came from.
    # @return [String, nil] (nil)
    attr_accessor :on_error

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
    # gives you a {Rack::Payment::Helper} object.
    # @return [String]
    attr_accessor :env_helper_variable

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
    #   Not yet implemented.  This will search for a YML file or ENV variable to set options.
    #   @param [#call] The Rack application for this middleware
    #
    # @overload initialize(rack_application, options)
    #   Accepts a Hash of options where the :gateway option is used as the {#gateway_type}
    #   @param [#call] The Rack application for this middleware
    #   @param [Hash] Options for the gateway and for Rack::Payment
    #
    def initialize rack_app = nil, options = nil
      options ||= {}
      options = look_for_options_in_a_yml_file.merge(options) unless options['yml_config'] == false or options[:yml_config] == false
      raise ArgumentError, "You must pass options (or put them in a yml file)." if options.empty?
      raise ArgumentError, 'You must pass a valid Rack application' unless rack_app.nil? or rack_app.respond_to?(:call)

      @app             = rack_app
      @gateway_options = options
      @gateway_type    = options['gateway'] || options[:gateway]

      # Before trying to instantiate a gateway using these options, let's remove *our* options so we 
      # don't end up passing them to the gateway's constructor, possibly blowing it up!

      @test_mode = @gateway_options.delete(:test_mode)  if @gateway_options.keys.include?(:test_mode)
      @test_mode = @gateway_options.delete('test_mode') if @gateway_options.keys.include?('test_mode')
      ActiveMerchant::Billing::Base.mode = (@test_mode == false) ? :production : :test unless @test_mode.nil?

      DEFAULT_OPTIONS.each do |name, value|
        # set the default
        send "#{name}=", value

        # override the value from options, if passed
        if @gateway_options[name.to_s] 
          send "#{name.to_s}=", @gateway_options.delete(name.to_s)
        elsif @gateway_options[name.to_s.to_sym] 
          send "#{name.to_s.to_sym}=", @gateway_options.delete(name.to_s.to_sym)
        end
      end

      # Now we check to see if the gateway is OK
      raise ArgumentError, 'You must pass a valid Gateway'          unless @gateway_type and gateway.is_a?(ActiveMerchant::Billing::Gateway)
    end

    # The main Rack #call method required by every Rack application / middleware.
    # @param [Hash] The Rack Request environment variables
    def call env
      raise "Rack::Payment was not initialized with a Rack application and cannot be #call'd" unless @app
      env[env_instance_variable] ||= self   # make this instance available
      return Request.new(env, self).finish  # a Request object actually returns the response
    end

    # Looks for options in a yml file with a conventional name (using Rack::Payment.yml_file_names)
    # Returns an empty Hash, if no options are found from a yml file.
    # @return [Hash]
    def look_for_options_in_a_yml_file
      Rack::Payment.yml_file_names.each do |filename|
        if ::File.file?(filename)
          options = YAML.load_file(filename)

          # if the YAML loaded something and it's a Hash
          if options and options.is_a?(Hash)

            # handle RACK_ENV / RAILS_ENV so you can put your test/development/etc in the same file
            if ENV['RACK_ENV'] and options[ENV['RACK_ENV']].is_a?(Hash)
              options = options[ENV['RACK_ENV']]
            elsif ENV['RAILS_ENV'] and options[ENV['RAILS_ENV']].is_a?(Hash)
              options = options[ENV['RAILS_ENV']]
            end

            return options
          end
        end
      end

      return {}
    end

    # Returns a new {Rack::Payment::Helper} instance which can be 
    # used to fire off single payments (without needing to make 
    # web requests).
    # @return [Rack::Payment::Helper]
    def payment
      Rack::Payment::Helper.new(self)
    end

  end
end
