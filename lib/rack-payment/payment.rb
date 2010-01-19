module Rack #:nodoc:

  # Here be Payment doco ...
  class Payment

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

    attr_accessor :app

    # PATHS
    attr_accessor :on_success
    attr_accessor :built_in_form_path
    attr_accessor :express_ok_path
    attr_accessor :express_cancel_path
    attr_accessor :env_instance_variable
    attr_accessor :env_data_variable
    attr_accessor :session_variable
    attr_accessor :rack_session_variable

    attr_accessor :gateway_type
    attr_accessor :gateway_options
    attr_writer   :gateway
    attr_writer   :paypal_express_gateway

    # Uses the #gateway_options to instantiate a [paypal] express gateway
    #
    # If your main gateway is a PaypayGateway, we'll make a PaypalExpressGateway
    # If your main gateway is a BogusGateway, we'll make a BogusExpressGateway
    #
    # For any gateway, we'll try to make a *ExpressGateway
    #
    # This ONLY works for classes underneath ActiveMerchant::Billing
    def express_gateway
      @paypal_express_gateway ||= ActiveMerchant::Billing::Base.gateway(express_gateway_type).new(gateway_options)
    end

    # Uses the class of #gateway to determine 
    def express_gateway_type
      gateway.class.to_s.split('::').last.sub(/(\w+)Gateway$/, '\1_express')
    end

    # uses the #gateway_type and #gateway_options to instantiate a gateway
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

    # @param [#call]     Rack application
    # @param [#purchase] {ActiveMerchant::Billing::Gateway}
    # @param [Hash]      Overrides for any of the {DEFAULT_OPTIONS}
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

    # @param [Hash] The Rack Request environment variables
    def call env

      # make this instance of Rack::Payment available
      env[env_instance_variable] ||= self

      # create a new Request, which wraps an individual request 
      # and get a Rack response from it
      return Request.new(env, self).finish
    end

  end
end
