# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  module Type
    # Custom type for arrays of both StructuredParams::Params objects and primitive types
    #
    # Usage examples:
    #   # Array of nested objects
    #   attribute :hobbies, :array, value_class: HobbyParameter
    #
    #   # Array of primitive types
    #   attribute :tags, :array, value_type: :string
    class Array < ActiveModel::Type::Value
      attr_reader :item_type #: ActiveModel::Type::Value

      # value_class or value_type is required
      #: (?value_class: singleton(StructuredParams::Params)?, ?value_type: Symbol?, **untyped) -> void
      def initialize(value_class: nil, value_type: nil, **options)
        super()
        validate_parameters!(value_class, value_type)
        @item_type = build_item_type(value_class, value_type, options)
      end

      #: () -> Symbol
      def type
        :array
      end

      # Cast value to array and convert each element to appropriate type
      #: (untyped) -> ::Array[untyped]?
      def cast(value)
        return nil if value.nil?

        ensure_array(value).map { |item| cast_item(item) }
      end

      # Serialize array (convert each element to Hash)
      #: (::Array[untyped]?) -> ::Array[untyped]?
      def serialize(value)
        return nil if value.nil?
        return [] unless value.is_a?(::Array)

        value.map { |item| @item_type.serialize(item) }
      end

      # Get permitted parameter names for use with Strong Parameters
      #: () -> ::Array[untyped]
      def permit_attribute_names
        return [] unless item_type_is_structured_params_object?

        @item_type.permit_attribute_names
      end

      # Determine if item type is StructuredParams::Object
      #: () -> bool
      def item_type_is_structured_params_object?
        @item_type.is_a?(StructuredParams::Type::Object)
      end

      private

      # Cast single item (delegate to new method)
      #: (untyped) -> untyped
      def cast_item(item)
        if item_type_is_structured_params_object?
          @item_type.value_class.new(item)
        else
          @item_type.cast(item)
        end
      end

      # Parameter validation
      #: (singleton(StructuredParams::Params)?, Symbol?) -> void
      def validate_parameters!(value_class, value_type)
        if value_class && value_type
          raise ArgumentError, 'Specify either value_class or value_type, not both'
        elsif !value_class && !value_type
          raise ArgumentError, 'Either value_class or value_type must be specified'
        elsif value_class && !(value_class <= StructuredParams::Params)
          raise ArgumentError, "value_class must inherit from StructuredParams::Params, got #{value_class}"
        end
      end

      # Build item type
      #: (singleton(StructuredParams::Params)?, Symbol?, Hash[untyped, untyped]) -> ActiveModel::Type::Value
      def build_item_type(value_class, value_type, options)
        if value_class
          StructuredParams::Type::Object.new(value_class: value_class)
        else
          ActiveModel::Type.lookup(value_type, **options)
        end
      end

      # Convert value to array
      #: (untyped) -> ::Array[untyped]
      def ensure_array(value)
        value.is_a?(::Array) ? value : [value]
      end
    end
  end
end
