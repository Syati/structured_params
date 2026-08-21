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
        # @rbs @entries: Array[Array[untyped]]?

        #: (singleton(StructuredParams::Params), **untyped) -> void
        def register(parameter_class, schema: nil, pointer: nil, property_names: {}, required_validation: :presence)
          entries << [
            parameter_class,
            {
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
          entries.each { |parameter_class, options| checks[parameter_class] = options }
          checks.map { |parameter_class, options| DriftCheck.call(parameter_class: parameter_class, **options) }
        end

        #: (?auto_discover: bool) -> Array[DriftCheck::Result]
        def check_all!(auto_discover: false)
          results = check_all(auto_discover: auto_discover)
          errors = results.reject(&:valid?).map(&:to_message)
          raise DriftError, errors.join("\n\n") unless errors.empty?

          results
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
      end
    end
  end
end
