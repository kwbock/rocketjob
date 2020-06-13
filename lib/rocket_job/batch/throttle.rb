require "active_support/concern"

module RocketJob
  module Batch
    # Rocket Job Batch Throttling Framework.
    #
    # Example:
    #   # Do not run any slices for this job when the MySQL slave delay exceeds 5 minutes.
    #   class MyJob < RocketJob::Job
    #     include RocketJob::Batch
    #
    #     # Define a custom mysql throttle
    #     # Prevents all slices from this job from running on the current server.
    #     define_batch_throttle :mysql_throttle_exceeded?
    #
    #     def perform(record)
    #       # ....
    #     end
    #
    #     private
    #
    #     # Returns true if the MySQL slave delay exceeds 5 minutes
    #     def mysql_throttle_exceeded?
    #       status        = ActiveRecord::Base.connection.connection.select_one('show slave status')
    #       seconds_delay = Hash(status)['Seconds_Behind_Master'].to_i
    #       seconds_delay >= 300
    #     end
    #   end
    module Throttle
      extend ActiveSupport::Concern

      included do
        class_attribute :rocket_job_batch_throttles
      end

      module ClassMethods
        # Add a new throttle.
        #
        # Parameters:
        #   method_name: [Symbol]
        #     Name of method to call to evaluate whether a throttle has been exceeded.
        #     Note: Must return true or false.
        #   filter: [Symbol|Proc]
        #     Name of method to call to return the filter when the throttle has been exceeded.
        #     Or, a block that will return the filter.
        #     Default: :throttle_filter_class (Throttle all jobs of this class)
        #
        # Note: Throttles are executed in the order they are defined.
        def define_batch_throttle(method_name, filter: :throttle_filter_class)
          # Duplicate to prevent modifying parent class throttles
          definitions = rocket_job_batch_throttles ? rocket_job_batch_throttles.dup : ThrottleDefinitions.new
          definitions.add(method_name, filter)
          self.rocket_job_batch_throttles = definitions
        end

        # Undefine a previously defined throttle
        def undefine_batch_throttle(method_name)
          return unless rocket_job_batch_throttles

          definitions = rocket_job_batch_throttles.dup
          definitions.remove(method_name)
          self.rocket_job_batch_throttles = definitions
        end

        # Has a throttle been defined?
        def batch_throttle?(method_name)
          rocket_job_batch_throttles.exist?(method_name)
        end
      end
    end
  end
end
