# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # OpenAPI contract registration and bulk execution utilities.
  module OpenApi
    # Raised by Registry.check_all! when one or more registered contracts drift.
    class DriftError < StandardError; end

    # Collects exceptional mappings and runs all configured drift checks.
    class Registry
      class << self
        # @rbs self.@entries: Array[Array[untyped]]?

        # +parameter_class+ may be a class name String (e.g. from a Rails initializer,
        # before Zeitwerk autoloading is set up); it is resolved lazily in +check_all+.
        # +openapi+ (a file path or Hash) overrides the configured document for this class, so
        # one app can check classes against several OpenAPI files.
        #: (singleton(StructuredParams::Params) | String, **untyped) -> void
        # rubocop:disable-next Metrics/ParameterLists
        def register(parameter_class, openapi: nil, schema: nil, pointer: nil, property_names: {},
                     required_validation: :presence)
          entries << [
            parameter_class,
            {
              openapi: openapi,
              schema: schema,
              pointer: pointer,
              property_names: property_names,
              required_validation: required_validation
            }
          ]
        end

        #: (?auto_discover: bool) -> Array[DriftCheck::Result]
        def check_all(auto_discover: false)
          checks = auto_discover ? auto_discovered_checks : {}
          entries.each { |parameter_class, options| checks[resolve(parameter_class)] = options }
          checks.map { |parameter_class, options| DriftCheck.call(parameter_class: parameter_class, **options) }
        end

        # With +strict+, a check that skipped part of a schema also fails the run.
        #: (?auto_discover: bool, ?strict: bool) -> Array[DriftCheck::Result]
        def check_all!(auto_discover: false, strict: false)
          results = check_all(auto_discover: auto_discover)
          failing = results.reject { |result| result.valid? && (!strict || result.skipped.empty?) }
          errors = failing.map(&:to_message)
          # Leading blank line so the first class's message doesn't get glued onto the
          # "ClassName: " prefix Ruby/Rake print ahead of an exception's message.
          raise DriftError, "\n\n#{errors.join("\n\n")}" unless errors.empty?

          results
        end

        # Describes what passing checks skipped or ignored, plus a one-line summary.
        #: (Array[DriftCheck::Result]) -> String
        def report(results)
          return 'No parameter classes were checked; set parameter_class_filter or register classes.' if results.empty?

          skipped = results.count { |result| !result.skipped.empty? }
          ignored = results.count { |result| !result.ignored.empty? }
          sections = results.map(&:to_report).reject(&:empty?)
          sections << "Checked #{results.size} classes: #{skipped} with skipped checks, " \
                      "#{ignored} with ignored findings."
          sections.join("\n\n")
        end

        #: () -> void
        def clear
          @entries = []
        end

        private

        #: () -> Hash[singleton(StructuredParams::Params), Hash[untyped, untyped]]
        def auto_discovered_checks
          OpenApi.configuration.parameter_classes.to_h { |parameter_class| [parameter_class, {}] }
        end

        #: () -> Array[Array[untyped]]
        def entries
          @entries ||= []
        end

        #: (singleton(StructuredParams::Params) | String) -> singleton(StructuredParams::Params)
        def resolve(parameter_class)
          parameter_class.is_a?(String) ? Object.const_get(parameter_class) : parameter_class
        end
      end
    end
  end
end
