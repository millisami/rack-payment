module Rack     #:nodoc:
  class Payment #:nodoc:

    class CreditCard
      attr_accessor :active_merchant_card

      def initialize
        @active_merchant_card ||= ActiveMerchant::Billing::CreditCard.new
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

      def update options
        options.each {|key, value| send "#{key}=", value }
      end

      # Aliases

      def cvv()       verification_value         end
      def cvv=(value) verification_value=(value) end

      def expiration_year()       year         end
      def expiration_year=(value) year=(value) end

      def expiration_month()       month         end
      def expiration_month=(value) month=(value) end

      def type
        active_merchant_card.type
      end

    end

  end
end
