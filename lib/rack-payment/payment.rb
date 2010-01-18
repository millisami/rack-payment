module Rack #:nodoc:

  # Here be Payment doco ...
  class Payment

    DEFAULT_OPTIONS = { }

    attr_accessor :app

    attr_accessor :gateway

    attr_accessor :on_success

    # @param [#call]     Rack application
    # @param [#purchase] {ActiveMerchant::Billing::Gateway}
    # @param [Hash]      Overrides for any of the {DEFAULT_OPTIONS}
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

      # make this instance of Rack::Payment available
      env['rack.payment'] ||= self

      # create a new Request, which wraps an individual request 
      # and get a Rack response from it
      return Request.new(env).finish
    end

  end
end
