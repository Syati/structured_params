# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  module OpenApi
    class DriftCheck
      # Result of a single schema/class comparison.
      class Result
        attr_reader :errors, :skipped, :ignored #: Array[Issue]
        attr_reader :parameter_class #: singleton(::StructuredParams::Params)

        #: (singleton(::StructuredParams::Params), Array[Issue], Array[Issue], Array[Issue]) -> void
        def initialize(parameter_class, errors, skipped, ignored)
          @parameter_class = parameter_class
          @errors = errors
          @skipped = skipped
          @ignored = ignored
        end

        #: () -> bool
        def valid?
          errors.empty?
        end

        #: () -> String
        def to_message
          sections = []
          sections << "OpenAPI drift detected:\n#{format_issues(errors)}" unless valid?
          sections << "OpenAPI checks skipped:\n#{format_issues(skipped)}" unless skipped.empty?
          return '' if sections.empty?

          "#{class_label}\n#{sections.join("\n")}"
        end

        # Lists what a passing check still left unverified (skipped) or suppressed (ignored),
        # so those stay visible in CI output instead of only on the result object.
        #: () -> String
        def to_report
          sections = []
          sections << "OpenAPI checks skipped:\n#{format_issues(skipped)}" unless skipped.empty?
          sections << "OpenAPI findings ignored:\n#{format_issues(ignored)}" unless ignored.empty?
          return '' if sections.empty?

          "#{class_label}\n#{sections.join("\n")}"
        end

        private

        #: () -> String
        def class_label
          @parameter_class.name || @parameter_class.inspect
        end

        #: (Array[Issue]) -> String
        def format_issues(issues)
          issues.map { |issue| "- #{issue.path}: #{issue.message}" }.join("\n")
        end
      end
    end
  end
end
