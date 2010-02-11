module Rack         #:nodoc:
  class Payment     #:nodoc:
    module Billable #:nodoc:

      # Includes {Rack::Payment::Billable} into your class 
      # *and* adds DataMapper properties to your class.
      #
      # We assume that you're including this into a DataMapper::Resource!
      module DataMapper

        def self.included base
          base.send :include, Rack::Payment::Billable
          base.instance_eval do

            property :credit_card_number, String
            # add more ...

          end
        end

      end

    end
  end
end
