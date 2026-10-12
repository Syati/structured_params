# rbs_inline: enabled
# frozen_string_literal: true

require 'date'
require 'yaml'
require_relative 'drift_check/issue'
require_relative 'drift_check/result'

module StructuredParams
  # Schema comparison types for OpenAPI drift checks.
  module OpenAPI
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
      # @rbs @active_pairs: Array[Array[untyped]]

      # Finding kinds that can be raised as errors (and therefore matched by +ignore_drift+).
      ERROR_KINDS = %i[
        missing_attribute unexpected_attribute missing_presence_validation type_mismatch
        missing_schema unresolved_reference
      ].freeze #: Array[Symbol]

      # Options that stop a presence validator from enforcing presence on every validation.
      CONDITIONAL_PRESENCE_OPTIONS = %i[if unless on allow_nil allow_blank].freeze #: Array[Symbol]

      # Schema types that a +oneOf+/+anyOf+ of plain scalars may offer.
      SCALAR_SCHEMA_TYPES = %i[string integer number boolean].freeze #: Array[Symbol]

      class << self
        # rubocop:disable Metrics/ParameterLists
        #: (**untyped) -> Result
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
        # rubocop:enable Metrics/ParameterLists
      end

      # rubocop:disable Metrics/ParameterLists
      #: (**untyped) -> void
      def initialize(
        parameter_class:,
        openapi: nil,
        schema: nil,
        pointer: nil,
        property_names: {},
        required_validation: :presence
      )
        @openapi_source = openapi || OpenAPI.configuration.document_for(parameter_class)
        @schema_source = schema
        @parameter_class = parameter_class
        @pointer = pointer
        @property_names = property_names.transform_keys(&:to_sym).transform_values(&:to_s)
        @required_validation = required_validation
        @errors = []
        @skipped = []
        @ignored = []
        @active_pairs = [] #: Array[Array[untyped]]

        unless %i[presence none].include?(required_validation)
          raise ArgumentError, "required_validation must be :presence or :none, got #{required_validation.inspect}"
        end

        return if @schema_source.is_a?(Hash) || @openapi_source

        raise ArgumentError, 'configure an OpenAPI document or pass schema as a Hash'
      end
      # rubocop:enable Metrics/ParameterLists

      #: () -> Result
      def call
        @errors = []
        @skipped = []
        @ignored = []
        @active_pairs = []

        schema = load_root_schema
        check_object(resolve_references(schema, ''), @parameter_class, '') if schema
        Result.new(@parameter_class, @errors.dup.freeze, @skipped.dup.freeze, @ignored.dup.freeze)
      end

      private

      # A missing or mistyped schema means the class silently lost its contract coverage,
      # so it is an error (suppressible with +ignore_drift+) rather than a skip.
      #: () -> Hash[untyped, untyped]?
      def load_root_schema
        schema, @document = load_schema
        return schema if schema.is_a?(Hash)

        report_missing_schema('the selected schema is not an object')
      rescue IndexError => e # also covers KeyError
        report_missing_schema(e.message)
      end

      #: (String) -> nil
      def report_missing_schema(detail)
        error('(root)', :missing_schema,
              "no matching OpenAPI schema found (#{detail}); " \
              'check the schema_name_resolver convention or register an explicit schema name')
        nil
      end

      #: () -> [Hash[untyped, untyped], Hash[untyped, untyped]]
      def load_schema
        if @schema_source.is_a?(Hash)
          return [@schema_source, @schema_source] if selected_pointer.nil?

          return [resolve_pointer(@schema_source, selected_pointer), @schema_source]
        end

        document = load_document
        pointer = selected_pointer || OpenAPI.configuration.pointer_for(@parameter_class, @schema_source)
        [resolve_pointer(document, pointer), document]
      end

      #: () -> Hash[untyped, untyped]
      def load_document
        return @openapi_source if @openapi_source.is_a?(Hash)

        OpenAPI.configuration.load_document(@openapi_source)
      end

      #: () -> String?
      def selected_pointer
        return @pointer unless @pointer.nil? || @pointer.empty?
        return unless @schema_source.is_a?(String)

        OpenAPI.configuration.pointer_for(@parameter_class, @schema_source)
      end

      #: (Hash[untyped, untyped], singleton(StructuredParams::Params), String) -> void
      def check_object(schema, parameter_class, path)
        return if unresolved_reference?(schema) || skip_union?(schema, path)

        # Only ancestors are tracked (compared by structural equality), so a schema reused by
        # sibling properties is still compared each time while a self-referencing schema
        # stops silently at its second visit.
        pair = [schema, parameter_class]
        return if @active_pairs.include?(pair)

        @active_pairs.push(pair)
        begin
          check_object_properties(schema, parameter_class, path)
        ensure
          @active_pairs.pop
        end
      end

      #: (Hash[untyped, untyped], singleton(StructuredParams::Params), String) -> void
      # rubocop:disable-next Metrics/AbcSize
      def check_object_properties(schema, parameter_class, path)
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
          compare_property(value_for(properties, schema_attributes.fetch(attribute)),
                           attribute_types.fetch(attribute.to_s), join_path(path, attribute))
        end
      end

      #: (untyped, ActiveModel::Type::Value, String) -> void
      def compare_property(property_schema, attribute_type, path)
        unless property_schema.is_a?(Hash)
          skip(path, 'property schema is not an object')
          return
        end

        compare_type(resolve_references(property_schema, path), attribute_type, path)
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
          next if nullable_property?(schema, property, join_path(path, property))

          error(join_path(path, property), :missing_presence_validation,
                'required schema property has no unconditional presence validation')
        end
      end

      # A required property that the schema allows to be null must not demand +presence+,
      # which would reject the null the contract permits.
      #: (Hash[untyped, untyped], String, String) -> bool
      def nullable_property?(schema, property, path)
        property_schema = value_for(value_for(schema, 'properties') || {}, property)
        return false unless property_schema.is_a?(Hash)

        resolved = without_reporting { resolve_references(property_schema, path) }
        nullable_schema?(resolved)
      end

      #: (Hash[untyped, untyped]) -> bool
      def nullable_schema?(schema)
        return true if value_for(schema, 'nullable') == true
        return true if null_type?(value_for(schema, 'type'))

        %w[oneOf anyOf].any? do |key|
          Array(value_for(schema, key)).any? { |option| option.is_a?(Hash) && nullable_schema?(option) }
        end
      end

      #: (untyped) -> bool
      def null_type?(type)
        type == 'null' || (type.is_a?(Array) && type.include?('null'))
      end

      # Runs a lookup whose findings are reported elsewhere, so they are not recorded twice.
      #: [T] () { () -> T } -> T
      def without_reporting
        sizes = [@errors.size, @skipped.size, @ignored.size]
        yield
      ensure
        @errors.slice!(sizes[0]..)
        @skipped.slice!(sizes[1]..)
        @ignored.slice!(sizes[2]..)
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      #: (Hash[untyped, untyped], ActiveModel::Type::Value, String) -> void
      def compare_type(schema, attribute_type, path)
        return if unresolved_reference?(schema)

        scalar_types = scalar_union_types(schema, path)
        return compare_scalar_union(scalar_types, attribute_type, path) if scalar_types
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
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      #: (Hash[untyped, untyped], Type::Array, String) -> void
      def compare_array_item_type(schema, attribute_type, path)
        items = value_for(schema, 'items')
        unless items.is_a?(Hash)
          skip(path, 'array schema has no items declaration')
          return
        end

        compare_type(resolve_references(items, "#{path}[]"), attribute_type.item_type, "#{path}[]")
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
        return %i[date datetime time string].include?(attribute_type) if schema_type == :string
        return %i[integer big_integer].include?(attribute_type) if schema_type == :integer

        schema_type == attribute_type
      end

      #: (singleton(StructuredParams::Params), Symbol) -> bool
      def presence_validator?(parameter_class, attribute)
        parameter_class._validators.fetch(attribute.to_sym, []).any? do |validator|
          validator.kind == :presence && validator.options.slice(*CONDITIONAL_PRESENCE_OPTIONS).empty?
        end
      end

      # A +oneOf+/+anyOf+ of plain scalars matches when the attribute fits any of them.
      #: (Array[Symbol], ActiveModel::Type::Value, String) -> void
      def compare_scalar_union(types, attribute_type, path)
        actual_type = attribute_type.type
        return if types.any? { |type| compatible_types?(type, actual_type) }

        error(path, :type_mismatch, "schema types #{types.inspect} do not match attribute type #{actual_type.inspect}")
      end

      # The scalar types offered by a +oneOf+/+anyOf+, or nil when it is not a plain scalar union.
      #: (Hash[untyped, untyped], String) -> Array[Symbol]?
      def scalar_union_types(schema, path)
        key = union_key(schema)
        return unless key

        options = value_for(schema, key).reject { |option| null_option?(option) }
        types = options.map { |option| scalar_option_type(option, path) }
        types if types.size > 1 && types.all? { |type| SCALAR_SCHEMA_TYPES.include?(type) }
      end

      #: (untyped, String) -> Symbol?
      def scalar_option_type(option, path)
        return unless option.is_a?(Hash)

        # Not silenced: a dangling $ref in an option must surface as :unresolved_reference.
        resolved = resolve_references(option, path)
        schema_type(resolved) unless value_for(resolved, 'properties')
      end

      #: (Hash[untyped, untyped]) -> String?
      def union_key(schema)
        %w[oneOf anyOf].find { |name| value_for(schema, name).is_a?(Array) }
      end

      # +oneOf: [X, {type: null}]+ and +type: [T, 'null']+ are how OpenAPI 3.1 says "X or null".
      # Collapse them to X and mark the result +nullable+, so they are compared like a 3.0
      # +nullable: true+ schema instead of being treated as unsupported unions.
      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def collapse_nullable(schema)
        collapse_null_type(schema) || collapse_null_union(schema) || schema
      end

      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]?
      def collapse_null_type(schema)
        type = value_for(schema, 'type')
        return unless type.is_a?(Array) && type.include?('null')

        others = type - ['null']
        schema.merge('type' => others.first, 'nullable' => true) if others.size == 1
      end

      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]?
      def collapse_null_union(schema)
        key = union_key(schema)
        return unless key

        options = value_for(schema, key)
        present = options.reject { |option| null_option?(option) }
        return unless present.size == 1 && present.size < options.size

        nullable_option(present.first, schema.reject { |name, _| name.to_s == key })
      end

      #: (untyped, Hash[untyped, untyped]) -> Hash[untyped, untyped]?
      def nullable_option(option, siblings)
        option.merge(siblings).merge('nullable' => true) if option.is_a?(Hash)
      end

      #: (untyped) -> bool
      def null_option?(option)
        option.is_a?(Hash) && null_type?(value_for(option, 'type')) && !value_for(option, 'type').is_a?(Array)
      end

      #: (Hash[untyped, untyped], String) -> bool
      def skip_union?(schema, path)
        union_key = %w[oneOf anyOf allOf].find { |key| value_for(schema, key) }
        return false unless union_key

        skip(path, "#{union_key} is outside the supported drift-check scope")
        true
      end

      #: (Hash[untyped, untyped], String, ?Array[String]) -> Hash[untyped, untyped]
      def resolve_references(schema, path, followed = [])
        schema = collapse_nullable(unwrap_single_all_of(schema))
        reference = value_for(schema, '$ref')
        return schema unless reference

        unless reference.start_with?('#/')
          skip(path, "external reference #{reference.inspect} is outside the supported drift-check scope")
          return schema
        end

        referenced_schema = fetch_reference(reference, path, followed)
        return schema unless referenced_schema

        overrides = schema.reject { |key, _| key.to_s == '$ref' }
        resolve_references(referenced_schema.merge(overrides), path, followed + [reference])
      end

      # A dangling or circular local reference is a broken contract, not an unsupported feature.
      #: (String, String, Array[String]) -> Hash[untyped, untyped]?
      def fetch_reference(reference, path, followed)
        return unresolved_reference(path, reference, 'it refers back to itself') if followed.include?(reference)

        target = resolve_pointer(@document, reference.delete_prefix('#'))
        return target if target.is_a?(Hash)

        unresolved_reference(path, reference, 'it does not point to a schema object')
      rescue IndexError => e # also covers KeyError
        unresolved_reference(path, reference, e.message)
      end

      #: (String, String, String) -> nil
      def unresolved_reference(path, reference, detail)
        error(display_path(path), :unresolved_reference,
              "reference #{reference.inspect} could not be resolved (#{detail})")
        nil
      end

      # A `$ref` left after resolve_references was already reported (skipped if external, an
      # error if unresolvable), so comparing it further would only add misleading findings.
      #: (Hash[untyped, untyped]) -> bool
      def unresolved_reference?(schema)
        !value_for(schema, '$ref').nil?
      end

      # OpenAPI/JSON Schema forbid sibling keys next to `$ref`, so generators such as TypeSpec
      # commonly wrap a single `$ref` in `allOf` to attach a `description`, `default`, etc.
      # That's equivalent to the ref carrying those siblings directly, so unwrap and merge a
      # single-entry `allOf` (typically a `$ref`, though an inline schema is unwrapped the same
      # way) instead of treating it as unsupported schema composition. `allOf` with more than
      # one entry is genuine composition and stays out of scope (reported via skip_union?).
      #: (Hash[untyped, untyped]) -> Hash[untyped, untyped]
      def unwrap_single_all_of(schema)
        all_of = value_for(schema, 'allOf')
        return schema unless all_of.is_a?(Array) && all_of.size == 1

        overrides = schema.reject { |key, _| key.to_s == 'allOf' }
        all_of.first.merge(overrides)
      end

      #: (untyped, String) -> untyped
      def resolve_pointer(document, pointer)
        pointer.delete_prefix('#').delete_prefix('/').split('/').reduce(document) do |value, segment|
          dig_pointer_segment(value, segment.gsub('~1', '/').gsub('~0', '~'))
        end
      end

      #: (untyped, String) -> untyped
      def dig_pointer_segment(value, segment)
        case value
        when Hash then value.fetch(segment)
        when Array then value.fetch(Integer(segment))
        else raise KeyError, "key not found: #{segment.inspect}"
        end
      rescue ArgumentError
        raise KeyError, "key not found: #{segment.inspect}"
      end

      #: (Hash[untyped, untyped], String) -> untyped
      def value_for(hash, key)
        hash[key] || hash[key.to_sym]
      end

      #: (untyped) -> Symbol
      def attribute_name(property)
        @property_names.invert.fetch(property.to_s, property).to_sym
      end

      #: (String, String) -> String
      def join_path(path, name)
        path.empty? ? name.to_s : "#{path}.#{name}"
      end

      #: (String, Symbol, String) -> void
      def error(path, kind, message)
        issue = Issue.new(kind: kind, path: path, message: message)
        target = OpenAPI.configuration.ignored?(kind, path, @parameter_class) ? @ignored : @errors
        target << issue
      end

      #: (String) -> String
      def display_path(path)
        path.empty? ? '(root)' : path
      end

      #: (String, String) -> void
      def skip(path, message)
        @skipped << Issue.new(kind: :unsupported, path: display_path(path), message: message)
      end
    end
  end
end
