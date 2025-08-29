# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  module Type
    # Custom type for single StructuredParams::Params objects
    class Object < ActiveModel::Type::Value
      attr_reader :value_class #: singleton(StructuredParams::Params)

      # Get permitted parameter names for use with Strong Parameters
      # @rbs!
      #  def permit_attribute_names: () -> ::Array[untyped]
      delegate :permit_attribute_names, to: :value_class

      #: (value_class: singleton(StructuredParams::Params), **untyped) -> void
      def initialize(value_class:, **_options)
        super()
        validate_value_class!(value_class)
        @value_class = value_class
      end

      #: () -> Symbol
      def type
        :object
      end

      # Cast value to StructuredParams::Params instance
      #: (untyped) -> StructuredParams::Params?
      def cast(value)
        return nil if value.nil?
        return value if value.is_a?(@value_class)

        @value_class.new(value) # call new directly instead of cast_value method
      end

      # Serialize (convert to Hash) the object
      #: (untyped) -> untyped
      def serialize(value)
        return nil if value.nil?

        value.is_a?(@value_class) ? value.attributes : value
      end

      private

      # Validate the class
      #: (untyped) -> void
      def validate_value_class!(value_class)
        raise ArgumentError, 'value_class must inherit from StructuredParams::Params, got NilClass' if value_class.nil?
        raise ArgumentError, "value_class must be a Class, got #{value_class.class}" unless value_class.is_a?(Class)

        return if value_class < StructuredParams::Params

        raise ArgumentError, "value_class must inherit from StructuredParams::Params, got #{value_class}"
      end
    end
  end
end
