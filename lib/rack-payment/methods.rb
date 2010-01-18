module Rack     #:nodoc:
  class Payment #:nodoc:

    # ...
    module Methods

      def payment
        payment_request_env['rack.payment.data'] ||= Rack::Payment::Data.new
      end

      # [Internal] this method returns the Rack 'env' for the current request.
      #
      # This looks for #env or #request.env by default.  If these don't return 
      # something, then we raise an exception and you should override this method 
      # so it returns the Rack env that we need.
      #
      # TODO lots of middleware might use a method like this ... refactor out?
      def payment_request_env
        if respond_to?(:env)
          env
        elsif respond_to?(:request) and request.respond_to?(:env)
          request.env
        else
          raise "Couldn't find 'env' ... please override #payment_request_env"
        end
      end

    end

  end
end
