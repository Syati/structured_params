# rbs_inline: enabled
# frozen_string_literal: true

require 'yaml'

module StructuredParams
  # Schema comparison types for OpenAPI drift checks.
  module OpenApi
    # Compares OpenAPI object schemas with StructuredParams declarations.
    # rubocop:disable-next Metrics/ClassLength
    class DriftCheck
      # @rbs @openapi_source: Hash[untyped, untyped]|String?
      # @rbs @schema_source: Hash[untyped, untyped]|String?
      # @rbs @parameter_class: singleton(::StructuredParams::Params)
      # @rbs @pointer: String?
      # @rbs @property_names: Hash[Symbol, String]
      # @rbs @required_validation: :presence|:none
      # @rbs @document: Hash[untyped, untyped]?
      # @rbs @errors: Array[Issue]
      # @rbs @skipped: Array[Issue]
      # @rbs @ignored: Array[Issue]
      # @rbs @seen_pairs: Array[Array[untyped]]

      Issue = Struct.new(
        :kind,     #: Symbol
        :path,     #: String
        :message,  #: String
        keyword_init: true
      )

      # Result of a single schema/class comparison.
      class Result
        # @rbs @parameter_class: singleton(::StructuredParams::Params)

        attr_reader :errors, :skipped, :ignored #: Array[Issue]

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

          "#{@parameter_class.name || @parameter_class.inspect}\n#{sections.join("\n")}"
        end

        private

        #: (Array[Issue]) -> String
        def format_issues(issues)
          issues.map { |issue| "- #{issue.path}: #{issue.message}" }.join("\n")
        end
      end

      class << self
        #: (**untyped) -> Result
        # rubocop:disable-next Metrics/ParameterLists
        def call(
          parameter_class:,
          openapi: nil,
          schema: nil,
          pointer: nil,
          property_names: {},
          required_validation: :presence
        )
          new(
            openapi: openapi,
            schema: schema,
            parameter_class: parameter_class,
            pointer: pointer,
            property_names: property_names,
            required_validation: required_validation
          ).call
        end
      end

      #: (**untyped) -> void
      # rubocop:disable-next Metrics/ParameterLists
      def initialize(
        parameter_class:,
        openapi: nil,
        schema: nil,
        pointer: nil,
        property_names: {},
        required_validation: :presence
      )
        @openapi_source = openapi || OpenApi.configuration.document
        @schema_source = schema
        @parameter_class = parameter_class
        @pointer = pointer
        @property_names = property_names.transform_keys(&:to_sym).transform_values(&:to_s)
        @required_validation = required_validation
        @errors = []
        @skipped = []
        @ignored = []
        @seen_pairs = [] #: Array[Array[untyped]]

        unless %i[presence none].include?(required_validation)
          raise ArgumentError, "required_validation must be :presence or :none, got #{required_validation.inspect}"
        end

        return if @schema_source.is_a?(Hash) || @openapi_source

        raise ArgumentError, 'configure an OpenAPI document or pass schema as a Hash'
      end

      #: () -> Result
      def call
        begin
          schema, @document = load_schema
        rescue KeyError => e
          skip('', "no matching OpenAPI schema found (#{e.message}); " \
                   'check the schema_name_resolver convention or register an explicit schema name')
          return Result.new(@parameter_class, @errors, @skipped, @ignored)
        end

        check_object(resolve_references(schema), @parameter_class, '')
        Result.new(@parameter_class, @errors, @skipped, @ignored)
      end

      private

      #: () -> Array[Hash[untyped, untyped]]
      def load_schema
        if @schema_source.is_a?(Hash)
          return [@schema_source, @schema_source] if selected_pointer.nil?

          return [resolve_pointer(@schema_source, selected_pointer), @schema_source]
        end

        document = load_document
        pointer = selected_pointer || OpenApi.configuration.pointer_for(@parameter_class, @schema_source)
        [resolve_pointer(document, pointer), document]
      end

      #: () -> Hash[untyped, untyped]
      def load_document
        return @openapi_source if @openapi_source.is_a?(Hash)

        YAML.safe_load_file(@openapi_source, aliases: true)
      end

      #: () -> String?
      def selected_pointer
        return @pointer unless @pointer.nil? || @pointer.empty?
        return unless @schema_source.is_a?(String)

        OpenApi.configuration.pointer_for(@parameter_class, @schema_source)
      end

      #: (Hash[untyped, untyped], singleton(StructuredParams::Params), String) -> void
      # rubocop:disable-next Metrics/AbcSize
      def check_object(schema, parameter_class, path)
        return if skip_union?(schema, path)
        return if seen?(schema, parameter_class)

        properties = value_for(schema, 'properties')
        unless properties.is_a?(Hash)
          skip(path, 'schema has no properties; only object schemas are supported')
          return
        end

        schema_attributes = properties.keys.to_h { |name| [attribute_name(name), name.to_s] }
        attribute_types = parameter_class.attribute_types
        compare_attribute_names(schema_attributes, attribute_types, path)
        compare_required_attributes(schema, schema_attributes, parameter_class, path)

        (schema_attributes.keys & attribute_types.keys.map(&:to_sym)).each do |attribute|
          property_schema = resolve_references(value_for(properties, schema_attributes.fetch(attribute)))
          compare_type(property_schema, attribute_types.fetch(attribute.to_s), join_path(path, attribute))
        end
      end

      #: (Hash[Symbol, String], Hash[String, ActiveModel::Type::Value], String) -> void
      def compare_attribute_names(schema_attributes, attribute_types, path)
        schema_attributes.each do |attribute, property|
          next if attribute_types.key?(attribute.to_s)

          error(join_path(path, property), :missing_attribute, 'schema property has no matching attribute declaration')
        end

        attribute_types.each_key do |attribute|
          next if schema_attributes.key?(attribute.to_sym)

          error(join_path(path, attribute), :unexpected_attribute,
                'attribute declaration has no matching schema property')
        end
      end

      #: (Hash[untyped, untyped], Hash[Symbol, String], singleton(StructuredParams::Params), String) -> void
      def compare_required_attributes(schema, schema_attributes, parameter_class, path)
        return if @required_validation == :none

        Array(value_for(schema, 'required')).each do |property|
          attribute = attribute_name(property)
          next unless schema_attributes.key?(attribute)
          next if presence_validator?(parameter_class, attribute)

          error(join_path(path, property), :missing_presence_validation,
                'required schema property has no unconditional presence validation')
        end
      end

      #: (Hash[untyped, untyped], ActiveModel::Type::Value, String) -> void
      # rubocop:disable-next Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def compare_type(schema, attribute_type, path)
        return if skip_union?(schema, path)

        if value_for(schema, 'type').is_a?(Array)
          skip(path, 'multiple schema types are outside the supported drift-check scope')
          return
        end

        expected_type = schema_type(schema)
        actual_type = attribute_type.type
        unless compatible_types?(expected_type, actual_type)
          error(path, :type_mismatch,
                "schema type #{expected_type.inspect} does not match attribute type #{actual_type.inspect}")
          return
        end

        if expected_type == :object && attribute_type.is_a?(Type::Object)
          check_object(schema, attribute_type.value_class, path)
        elsif expected_type == :array && attribute_type.is_a?(Type::Array)
          compare_array_item_type(schema, attribute_type, path)
        end
      end

      #: (Hash[untyped, untyped], Type::Array, String) -> void
      def compare_array_item_type(schema, attribute_type, path)
        items = value_for(schema, 'items')
        unless items.is_a?(Hash)
          skip(path, 'array schema has no items declaration')
          return
        end

        compare_type(resolve_references(items), attribute_type.item_type, "#{path}[]")
      end

      #: (Hash[untyped, untyped]) -> Symbol?
      def schema_type(schema)
        type = value_for(schema, 'type')
        return type.to_sym if type
        return :object if value_for(schema, 'properties').is_a?(Hash)

        nil
      end

      #: (Symbol?, Symbol) -> bool
      def compatible_types?(schema_type, attribute_type)
        return false if schema_type.nil?
        return %i[float decimal].include?(attribute_type) if schema_type == :number

        schema_type == attribute_type
      end

      #: (singleton(StructuredParams::Params), Symbol) -> bool
      def presence_validator?(parameter_class, attribute)
        parameter_class._validators.fetch(attribute.to_sym, []).any? do |validator|
          validator.kind == :presence && validator.options.slice(:if, :unless).empty?
        end
      end

      #: (Hash[untyped, untyped], String) -> bool
      def skip_union?(schema, path)
        union_key = %w[oneOf anyOf allOf].find { |key| value_for(schema, key) }
        return false unless union_key

        skip(path, "#{union_key} is outside the supported drift-check scope")
        true
      end

      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def resolve_references(schema)
        schema = unwrap_single_all_of(schema)
        reference = value_for(schema, '$ref')
        return schema unless reference

        unless reference.start_with?('#/')
          skip('', "external reference #{reference.inspect} is outside the supported drift-check scope")
          return schema
        end

        referenced_schema = resolve_pointer(@document, reference.delete_prefix('#'))
        overrides = schema.reject { |key, _| key.to_s == '$ref' }
        resolve_references(referenced_schema.merge(overrides))
      end

      # OpenAPI/JSON Schema forbid sibling keys next to `$ref`, so generators such as TypeSpec
      # commonly wrap a single `$ref` in `allOf` to attach a `description`, `default`, etc.
      # That's equivalent to the ref carrying those siblings directly, so unwrap and merge it
      # instead of treating it as unsupported schema composition. `allOf` with more than one
      # entry is genuine composition and stays out of scope (reported via skip_union?).
      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def unwrap_single_all_of(schema)
        all_of = value_for(schema, 'allOf')
        return schema unless all_of.is_a?(Array) && all_of.size == 1

        overrides = schema.reject { |key, _| key.to_s == 'allOf' }
        all_of.first.merge(overrides)
      end

      #: (Hash[untyped, untyped], String) -> Hash[untyped, untyped]
      def resolve_pointer(document, pointer)
        pointer.delete_prefix('#').delete_prefix('/').split('/').reduce(document) do |value, segment|
          value.fetch(segment.gsub('~1', '/').gsub('~0', '~'))
        end
      end

      #: (Hash[untyped, untyped], String) -> untyped
      def value_for(hash, key)
        hash[key] || hash[key.to_sym]
      end

      #: (untyped) -> Symbol
      def attribute_name(property)
        @property_names.invert.fetch(property.to_s, property).to_sym
      end

      #: (Hash[untyped, untyped], singleton(StructuredParams::Params)) -> bool
      def seen?(schema, parameter_class)
        pair = [schema.object_id, parameter_class]
        return true if @seen_pairs.include?(pair)

        @seen_pairs << pair
        false
      end

      #: (String, String) -> String
      def join_path(path, name)
        path.empty? ? name.to_s : "#{path}.#{name}"
      end

      #: (String, Symbol, String) -> void
      def error(path, kind, message)
        issue = Issue.new(kind: kind, path: path, message: message)
        target = OpenApi.configuration.ignored?(kind, path) ? @ignored : @errors
        target << issue
      end

      #: (String, String) -> void
      def skip(path, message)
        @skipped << Issue.new(kind: :unsupported, path: path.empty? ? '(root)' : path, message: message)
      end
    end
  end
end
