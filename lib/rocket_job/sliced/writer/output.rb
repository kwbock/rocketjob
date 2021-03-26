module RocketJob
  module Sliced
    module Writer
      # Internal class for writing categorized results into output slices
      class Output
        attr_reader :job, :categorized_records
        attr_accessor :input_slice

        # Collect output results and write to output collections
        # iff job is collecting output
        # Notes:
        #   Nothing is saved if an exception is raised inside the block
        def self.collect(job, input_slice = nil)
          if job.output_categories.present?
            writer = new(job, input_slice)
            yield(writer)
            writer.close
          else
            writer = NullWriter.new(job, input_slice)
            yield(writer)
          end
        end

        def initialize(job, input_slice = nil)
          @job                 = job
          @input_slice         = input_slice
          @categorized_records = {}
        end

        # Writes the supplied result, RocketJob::Batch::Result or RocketJob::Batch::Results
        # to the relevant collections
        def <<(result)
          if result.is_a?(RocketJob::Batch::Results)
            result.each { |single| extract_categorized_result(single) }
          else
            extract_categorized_result(result)
          end
        end

        # Write categorized results to their relevant collections
        def close
          categorized_records.each_pair do |category, results|
            job.output(category).insert(results, input_slice)
          end
        end

        private

        # Stores the categorized result from one result
        def extract_categorized_result(result)
          named_category = :main
          value          = result
          if result.is_a?(RocketJob::Batch::Result)
            named_category = result.category
            value          = result.value
          end
          (categorized_records[named_category] ||= []) << value unless value.nil? && !job.output_category(named_category).nils
        end
      end

      class NullWriter
        attr_reader :job, :categorized_records
        attr_accessor :input_slice

        def initialize(job, input_slice = nil)
          @job                 = job
          @input_slice         = input_slice
          @categorized_records = {}
        end

        def <<(_)
          # noop
        end

        def close
          # noop
        end
      end
    end
  end
end
