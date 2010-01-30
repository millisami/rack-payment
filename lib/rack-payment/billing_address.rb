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
        %w( name address1 city state zip ).each do |field|
          return true unless send(field).nil?
        end

        return false
      end

      # defaults to 'US'
      def country
        @country ||= 'US'
      end

      # Aliases

      def street()       address1              end
      def street=(value) self.address1=(value) end

      def address()       address1              end
      def address=(value) self.address1=(value) end

      def full_name()       name              end
      def full_name=(value) self.name=(value) end

      # Returns a hash that can be passed to a Gateway#authorize call
      def active_merchant_hash
        { 
          :name     => name,
          :address1 => street,
          :city     => city,
          :state    => state,
          :country  => country,
          :zip      => zip
        }
      end
    end

  end
end
