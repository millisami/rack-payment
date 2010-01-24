module Rack     #:nodoc:
  class Payment #:nodoc:

    class CreditCard

      REQUIRED = %w( first_name last_name type number month year verification_value )

      attr_accessor :active_merchant_card

      def initialize
        @active_merchant_card ||= ActiveMerchant::Billing::CreditCard.new
      end

      def [] key
        send key
      end

      def method_missing name, *args, &block
        if active_merchant_card.respond_to?(name)
          active_merchant_card.send(name, *args, &block)
        else
          super
        end
      end

      def partially_filled_out?
        %w( type number verification_value month year first_name last_name ).each do |field|
          return true unless send(field).nil?
        end

        return false
      end

      def fully_filled_out?
        # errors.empty?
        raise "Not yet spec'd"
      end

      def update options
        options.each {|key, value| send "#{key}=", value }
      end

      # Aliases

      def cvv()       verification_value              end
      def cvv=(value) self.verification_value=(value) end

      def expiration_year()       year              end
      def expiration_year=(value) self.year=(value) end

      def expiration_month()       month              end
      def expiration_month=(value) self.month=(value) end

      def type
        active_merchant_card.type
      end

      def full_name
        [ first_name, last_name ].compact.join(' ')
      end

      def errors
        REQUIRED.inject([]) do |errors, required_attribute_name|
          value = send required_attribute_name
          errors << "#{ required_attribute_name.titleize } is required" if value.nil? or value.empty?
          errors
        end
      end

    end

  end
end
