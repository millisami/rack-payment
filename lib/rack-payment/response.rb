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

      def express?
        express != nil
      end

      def amount_paid
        if success?
          if express?
            express_amound_paid
          else
            (raw_capture_response.params['paid_amount'].to_f / 100)
          end
        end
      end

      def express_amound_paid
        if success?
          raw_express_response.params['gross_amount'].to_f
        end
      end

      def success?
        if express?
          express_success?
        else
          auth and auth.success? and capture and capture.success?
        end
      end

      def express_success?
        raw_express_response.success?
      end

    end

  end
end
