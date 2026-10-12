# rbs_inline: enabled
# frozen_string_literal: true

require 'date'
require 'yaml'

module StructuredParams
  # OpenAPI contract configuration and drift-check utilities.
  module OpenAPI
    # Global OpenAPI document and component-name convention for drift checks.
    class Configuration
      # @rbs @ignored_issues: Array[Hash[Symbol, untyped]]
      # @rbs @documents: Hash[String, Array[untyped]]

      attr_accessor :document #: Hash[untyped, untyped]|String?
      attr_writer :schema_name_resolver #: untyped
      attr_writer :document_resolver #: untyped
      attr_writer :parameter_class_filter #: untyped

      #: () -> void
      def initialize
        @schema_name_resolver = lambda do |parameter_class|
          parameter_class.name.split('::').last.sub(/(?:Params?|Parameters?|Form)$/, '')
        end
        @ignored_issues = []
        @documents = {}
      end

      # The OpenAPI document for +parameter_class+: the +document_resolver+ result when it
      # returns one, otherwise the global +document+. Lets one app check classes from several
      # API namespaces (e.g. admin and front) against separate files.
      #: (singleton(StructuredParams::Params)) -> (Hash[untyped, untyped] | String)?
      def document_for(parameter_class)
        @document_resolver&.call(parameter_class) || document
      end

      # Parses an OpenAPI file once per modification time, so a bulk check across many
      # parameter classes does not re-read the same document for each of them. JSON files
      # work too, since JSON is valid YAML. Only the mtime invalidates the cache, so two writes
      # within the filesystem's timestamp granularity can serve a stale parse. YAML dates such as
      # `example: 2020-01-01` load as Date, hence +permitted_classes+.
      #: (String) -> Hash[untyped, untyped]
      def load_document(path)
        mtime = File.mtime(path)
        cached_mtime, document = @documents[path]
        return document if cached_mtime == mtime

        document = YAML.safe_load_file(path, aliases: true, permitted_classes: [Date, Time])
        unless document.is_a?(Hash)
          raise ArgumentError,
                "OpenAPI document #{path} must contain a mapping at its top level"
        end

        @documents[path] = [mtime, document]
        document
      end

      # Suppresses matching findings instead of raising them as errors. Each of +path+, +kind+
      # and +parameter_class+ narrows the rule; an omitted one matches everything, but at least
      # one must be given. Without +parameter_class+ the rule applies to every drift check,
      # including once per parent class for a nested object reused by several top-level
      # parameter classes. Skips (unsupported schema features) are never ignored; they only
      # appear in Result#skipped.
      #
      # Paths use attribute names joined with +.+ and +[]+ for array items, e.g.
      # +items[].sku+. A schema that cannot be found at all (+:missing_schema+) concerns the
      # whole class rather than a property, so omit +path+ for it.
      #
      # Ignored findings are moved to DriftCheck::Result#ignored rather than dropped, so
      # they stay auditable; #valid? and #to_message treat them as resolved.
      #: (?path: String?, ?kind: Symbol?, ?parameter_class: (Class | String)?) -> void
      def ignore_drift(path: nil, kind: nil, parameter_class: nil)
        if path.nil? && kind.nil? && parameter_class.nil?
          raise ArgumentError, 'give at least one of path:, kind: or parameter_class: to ignore_drift'
        end

        if kind && !DriftCheck::ERROR_KINDS.include?(kind)
          raise ArgumentError, "unknown kind #{kind.inspect}; expected one of #{DriftCheck::ERROR_KINDS.inspect}"
        end

        @ignored_issues << { path: path, kind: kind, parameter_class: parameter_class&.to_s }
      end

      #: (Symbol, String, ?untyped) -> bool
      def ignored?(kind, path, parameter_class = nil)
        @ignored_issues.any? do |rule|
          [nil, path].include?(rule.fetch(:path)) &&
            [nil, kind].include?(rule.fetch(:kind)) &&
            [nil, parameter_class&.to_s].include?(rule.fetch(:parameter_class))
        end
      end

      #: () -> Array[singleton(StructuredParams::Params)]
      def parameter_classes
        return [] unless @parameter_class_filter

        ObjectSpace.each_object(Class).select do |parameter_class|
          parameter_class < StructuredParams::Params && parameter_class.name &&
            @parameter_class_filter.call(parameter_class)
        end
      end

      #: (singleton(StructuredParams::Params), ?String?) -> String
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
