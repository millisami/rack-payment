# Helpers for testing Rack::Payment

module ActiveMerchant #:nodoc:
  module Billing      #:nodoc:

    # ...
    class BogusExpressGateway < BogusGateway
    end

  end
end
