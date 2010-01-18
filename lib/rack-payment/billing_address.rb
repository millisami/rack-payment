module Rack     #:nodoc:
  class Payment #:nodoc:

    class BillingAddress
      attr_accessor :name, :address1, :city, :state, :zip, :country

      def [] key
        send key
      end

      def update options
        options.each {|key, value| send "#{key}=", value }
      end

      def partially_filled_out?
        %w( name address1 city state zip country ).each do |field|
          return true unless send(field).nil?
        end

        return false
      end
    end

  end
end
