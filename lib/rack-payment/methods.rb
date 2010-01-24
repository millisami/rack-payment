module Rack     #:nodoc:
  class Payment #:nodoc:

    # This is intended to be included in your Rack/Sinatra/Rails application.
    #
    # It gives you a {#payment} object, which is the main API for working with {Rack::Payment}.
    #
    # It also gives you access to the instance of the {Rack::Payment} you included via {#rack_payment}
    module Methods

      # Returns an instance of {Rack::Payment::Helper}, which is the main API for working with {Rack::Payment}
      #
      # This assumes that this is available via env['rack.payment']
      #
      # If you override the {Rack::Payment#env_instance_variable}, you will need to 
      # pass that string as an option to {#rack_payment}
      def payment env_instance_variable = Rack::Payment::DEFAULT_OPTIONS['env_instance_variable']
        rack_payment_instance = rack_payment(env_instance_variable)
        _request_env[ rack_payment_instance.env_helper_variable ] ||= Rack::Payment::Helper.new(rack_payment_instance)
      end

      # Returns the instance of {Rack::Payment} your application is using.
      #
      # This assumes that this is available via env['rack.payment']
      #
      # If you override the {Rack::Payment#env_instance_variable}, you will need to 
      # pass that string as an option to {#rack_payment}
      def rack_payment env_instance_variable = Rack::Payment::DEFAULT_OPTIONS['env_instance_variable']
        _request_env[env_instance_variable]
      end

      # This method returns the Rack 'env' for the current request.
      #
      # This looks for #env or #request.env by default.  If these don't return 
      # something, then we raise an exception and you should override this method 
      # so it returns the Rack env that we need.
      #
      # @private
      def _request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) and request.respond_to?(:env)
          request.env
        else
          raise "Couldn't find 'env' ... please override #_request_env"
        end
      end

    end

  end
end
