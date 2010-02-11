

module Rack         #:nodoc:
  class Payment     #:nodoc:
    module Billable #:nodoc:

      # Includes {Rack::Payment::Billable} into your class 
      # *and* adds DataMapper properties to your class.
      #
      # We assume that you're including this into a DataMapper::Resource!
      #
      # We also assume that your class has a normal Serial Integer primary key.
      #
      # It also adds the associations and model classes for scheduled 
      # and completed payments because ... why not?
      #
      # We will make these associations more configurable when we add 
      # ActiveRecord support.
      module DataMapper

        class ScheduledPayment
          include ::DataMapper::Resource

          property :id,        Serial
          property :amount,    Float
          property :charge_at, DateTime
          property :parent_id, Integer
        end

        def self.included base
          base.send :include, Rack::Payment::Billable

          base.instance_eval do
            property :credit_card_number, String
            has n, :scheduled_payments, :model => ScheduledPayment, :child_key => :parent_id
          end
        end

      end

    end
  end
end
