# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Parameter model that supports nested structures
  #
  # Usage example:
  #   class UserParameter < StructuredParams::Params
  #     attribute :name, :string
  #     attribute :address, :nested, value_class: AddressParameter
  #     attribute :hobbies, :array, value_class: HobbyParameter
  #     attribute :tags, :array, value_type: :string
  #   end
  class Params
    include ActiveModel::Model
    include ActiveModel::Attributes

    class << self
      # Generate permitted parameter structure for Strong Parameters
      #: () -> Array[untyped]
      def permit_attribute_names
        attribute_types.map do |name, type|
          name = name.to_sym

          if type.is_a?(StructuredParams::Type::Object) || type.is_a?(StructuredParams::Type::Array)
            { name => type.permit_attribute_names }
          else
            name
          end
        end
      end

      # Get names of nested StructuredParams attributes
      #: () { (String) -> void } -> void
      def each_nested_attribute_name
        attribute_types.each do |name, type|
          yield name if structured_params_type?(type)
        end
      end

      private

      # Determine if the specified type is a nested parameter type
      #: (untyped) -> bool
      def structured_params_type?(type)
        type.is_a?(StructuredParams::Type::Object) ||
          (type.is_a?(StructuredParams::Type::Array) && type.item_type_is_structured_params_object?)
      end
    end

    # Integrate validation of nested objects
    validate :validate_nested_parameters

    #: (untyped) -> void
    def initialize(params)
      processed_params = process_input_parameters(params)
      super(**processed_params)
    end

    # Convert nested objects to Hash and get attributes
    #: (symbolize: bool) -> Hash[untyped, untyped]
    def attributes(symbolize: false)
      attrs = super()

      self.class.each_nested_attribute_name do |name|
        value = attrs[name.to_s]
        attrs[name.to_s] = serialize_nested_value(value)
      end

      symbolize ? attrs.deep_symbolize_keys : attrs
    end

    private

    # Process input parameters
    #: (untyped) -> Hash[untyped, untyped]
    def process_input_parameters(params)
      case params
      when ActionController::Parameters
        params.permit(self.class.permit_attribute_names).to_h
      when Hash
        # Convert symbol hash to string hash and recursively transform nested child elements
        deep_stringify_keys(params)
      else
        raise ArgumentError, "params must be ActionController::Parameters or Hash, got #{params.class}"
      end
    end

    # Deeply convert symbol hash to string hash (including child elements)
    #: (untyped) -> untyped
    def deep_stringify_keys(value)
      deep_transform_keys(value, &:to_s)
    end

    # Generic method to deeply transform keys (Rails-style deep_transform_keys)
    #: (untyped) { (untyped) -> untyped } -> untyped
    def deep_transform_keys(value, &block)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), result|
          result[yield(key)] = deep_transform_keys(val, &block)
        end
      when Array
        value.map { |item| deep_transform_keys(item, &block) }
      else
        value
      end
    end

    # Execute nested parameter validation
    #: () -> void
    def validate_nested_parameters
      self.class.each_nested_attribute_name do |attr_name|
        value = attribute(attr_name)
        next if value.blank?

        case value
        when Array
          validate_nested_array(attr_name, value)
        else
          validate_nested_object(attr_name, value)
        end
      end
    end

    # Validate nested arrays
    #: (String, Array[untyped]) -> void
    def validate_nested_array(attr_name, array_value)
      array_value.each_with_index do |item, index|
        next if item.valid?(validation_context)

        import_nested_errors(item.errors, "#{attr_name}_#{index}")
      end
    end

    # Validate nested objects
    #: (String, StructuredParams::Params) -> void
    def validate_nested_object(attr_name, object_value)
      return if object_value.valid?(validation_context)

      import_nested_errors(object_value.errors, attr_name)
    end

    # Integrate nested errors into parent errors
    #: (untyped, String) -> void
    def import_nested_errors(nested_errors, prefix)
      nested_errors.each do |error|
        error_key = "#{prefix}_#{error.attribute}"
        errors.add(error_key, error.message)
      end
    end

    # Serialize nested values
    #: (untyped) -> untyped
    def serialize_nested_value(value)
      case value
      when Array
        value.map(&:attributes)
      when StructuredParams::Params
        value.attributes
      else
        value
      end
    end
  end
end
