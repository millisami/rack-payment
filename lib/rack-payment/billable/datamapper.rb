require 'dm-types' # <--- i don't want any requirements in here!  i think?  Oo

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
          property :due_at,    DateTime
          property :parent_id, Integer
        end

        class CompletedPayment
          include ::DataMapper::Resource

          # we copy/paste these from the ScheduledPayment
          property :id,        Serial
          property :amount,    Float
          property :due_at,    DateTime
          property :parent_id, Integer

          # properties specific to a completed payment
          property :success,  Boolean
          property :response, Yaml
        end

        def self.included base
          base.send :include, Rack::Payment::Billable

          ScheduledPayment.instance_eval { belongs_to :parent, :model => base }
          CompletedPayment.instance_eval { belongs_to :parent, :model => base }

          base.instance_eval do
            property :credit_card_number,             String
            property :credit_card_first_name,         String
            property :credit_card_last_name,          String
            property :credit_card_type,               String
            property :credit_card_month,              String
            property :credit_card_year,               String
            property :credit_card_verification_value, String

            has n,   :scheduled_payments, :model => ScheduledPayment, :child_key => :parent_id
            has n,   :completed_payments, :model => CompletedPayment, :child_key => :parent_id
          end

          base.send :extend, ClassMethods
        end

        module ClassMethods

          def future_payments current_time = Time.now
            ScheduledPayment.all :due_at.gt => current_time
          end

          def due_payments current_time = Time.now
            ScheduledPayment.all :due_at.lte => current_time
          end

        end

      end

    end
  end
end
