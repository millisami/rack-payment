module Rack     #:nodoc:
  class Payment #:nodoc:

    # Represents the response you get when you try to make a purchase 
    # from ActiveMerchant
    class Response

      attr_accessor :raw_authorize_response
      attr_accessor :raw_capture_response
      attr_accessor :raw_express_response

      alias auth    raw_authorize_response
      alias capture raw_capture_response
      alias express raw_express_response

      def amount_paid
        (raw_capture_response.params['paid_amount'].to_f / 100) if success?
      end

      def success?
        auth and auth.success? and capture and capture.success?
      end

    end

  end
end
