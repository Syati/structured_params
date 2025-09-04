# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Parameter model that supports structured objects and arrays
  #
  # Usage example:
  #   class UserParameter < StructuredParams::Params
  #     attribute :name, :string
  #     attribute :address, :object, value_class: AddressParameter
  #     attribute :hobbies, :array, value_class: HobbyParameter
  #     attribute :tags, :array, value_type: :string
  #   end
  class Params
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ErrorFormatter

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

      # Get names of StructuredParams attributes (object and array types)
      #: () { (String) -> void } -> void
      def each_structured_attribute_name
        attribute_types.each do |name, type|
          yield name if structured_params_type?(type)
        end
      end

      private

      # Determine if the specified type is a StructuredParams type
      #: (untyped) -> bool
      def structured_params_type?(type)
        type.is_a?(StructuredParams::Type::Object) ||
          (type.is_a?(StructuredParams::Type::Array) && type.item_type_is_structured_params_object?)
      end
    end

    # Integrate validation of structured objects
    validate :validate_structured_parameters

    #: (untyped) -> void
    def initialize(params)
      processed_params = process_input_parameters(params)
      super(**processed_params)
    end

    # Convert structured objects to Hash and get attributes
    #: (symbolize: bool) -> Hash[untyped, untyped]
    def attributes(symbolize: false)
      attrs = super()

      self.class.each_structured_attribute_name do |name|
        value = attrs[name.to_s]
        attrs[name.to_s] = serialize_structured_value(value)
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
        # ActiveModel::Attributes can handle both symbol and string keys
        params
      else
        raise ArgumentError, "params must be ActionController::Parameters or Hash, got #{params.class}"
      end
    end

    # Execute structured parameter validation
    #: () -> void
    def validate_structured_parameters
      self.class.each_structured_attribute_name do |attr_name|
        value = attribute(attr_name)
        next if value.blank?

        case value
        when Array
          validate_structured_array(attr_name, value)
        else
          validate_structured_object(attr_name, value)
        end
      end
    end

    # Validate structured arrays
    #: (String, Array[untyped]) -> void
    def validate_structured_array(attr_name, array_value)
      array_value.each_with_index do |item, index|
        next if item.valid?(validation_context)

        error_path = format_error_path(attr_name, index)
        import_structured_errors(item.errors, error_path)
      end
    end

    # Validate structured objects
    #: (String, StructuredParams::Params) -> void
    def validate_structured_object(attr_name, object_value)
      return if object_value.valid?(validation_context)

      error_path = format_error_path(attr_name, nil)
      import_structured_errors(object_value.errors, error_path)
    end

    # Format error path using dot notation (always consistent)
    #: (String, Integer?) -> String
    def format_error_path(attr_name, index = nil)
      path_parts = [attr_name]
      path_parts << index.to_s if index
      path_parts.join('.')
    end

    # Integrate structured parameter errors into parent errors
    #: (untyped, String) -> void
    def import_structured_errors(structured_errors, prefix)
      structured_errors.each do |error|
        errors.import(error, attribute: :"#{prefix}.#{error.attribute}")
      end
    end

    # Serialize structured values
    #: (untyped) -> untyped
    def serialize_structured_value(value)
      case value
      when Array
        value.map { |item| item.attributes(symbolize: false) }
      when StructuredParams::Params
        value.attributes(symbolize: false)
      else
        value
      end
    end
  end
end
