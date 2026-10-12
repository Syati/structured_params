# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # OpenAPI contract configuration and drift-check utilities.
  module OpenApi
    # Global OpenAPI document and component-name convention for drift checks.
    class Configuration
      # @rbs @ignored_issues: Array[Hash[Symbol, untyped]]

      attr_accessor :document #: Hash[untyped, untyped]|String?
      attr_writer :schema_name_resolver #: untyped
      attr_writer :parameter_class_filter #: untyped

      #: () -> void
      def initialize
        @schema_name_resolver = lambda do |parameter_class|
          parameter_class.name.split('::').last.sub(/(?:Params?|Parameters?|Form)$/, '')
        end
        @ignored_issues = []
      end

      # Suppresses a specific finding (matched by +path+ and, optionally, +kind+) across
      # every drift check, instead of raising it as an error. Applies wherever that path
      # occurs, including once per parent class for a nested object reused by several
      # top-level parameter classes. Omit +kind+ to ignore every kind at that path.
      #
      # Ignored findings are moved to DriftCheck::Result#ignored rather than dropped, so
      # they stay auditable; #valid? and #to_message treat them as resolved.
      #: (path: String, ?kind: Symbol?) -> void
      def ignore_drift(path:, kind: nil)
        @ignored_issues << { path: path, kind: kind }
      end

      #: (Symbol, String) -> bool
      def ignored?(kind, path)
        @ignored_issues.any? { |rule| rule.fetch(:path) == path && [nil, kind].include?(rule.fetch(:kind)) }
      end

      #: () -> Array[singleton(StructuredParams::Params)]
      def parameter_classes
        return [] unless @parameter_class_filter

        ObjectSpace.each_object(Class).select do |parameter_class|
          parameter_class < StructuredParams::Params && @parameter_class_filter.call(parameter_class)
        end
      end

      #: (singleton(StructuredParams::Params), String?) -> String
      def pointer_for(parameter_class, schema_name = nil)
        name = schema_name || @schema_name_resolver.call(parameter_class)
        return name if name.start_with?('/', '#/')

        "/components/schemas/#{name.gsub('~', '~0').gsub('/', '~1')}"
      end
    end

    class << self
      # @rbs self.@configuration: Configuration?

      #: () -> Configuration
      def configuration
        @configuration ||= Configuration.new
      end

      #: () { (Configuration) -> void } -> void
      def configure
        yield configuration
      end

      #: () -> void
      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
