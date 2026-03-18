# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Parameter model that supports structured objects and arrays
  #
  # This class can be used in two ways:
  # 1. Strong Parameters validation (API requests)
  # 2. Form objects (View integration with form_with/form_for)
  #
  # Strong Parameters example (API):
  #   class UserParams < StructuredParams::Params
  #     attribute :name, :string
  #     attribute :address, :object, value_class: AddressParams
  #     attribute :hobbies, :array, value_class: HobbyParams
  #     attribute :tags, :array, value_type: :string
  #   end
  #
  #   # In controller:
  #   user_params = UserParams.new(params)
  #   if user_params.valid?
  #     User.create!(user_params.attributes)
  #   else
  #     render json: { errors: user_params.errors }
  #   end
  #
  # Form object example (View integration):
  #   class UserRegistrationForm < StructuredParams::Params
  #     attribute :name, :string
  #     attribute :email, :string
  #     validates :name, presence: true
  #     validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  #   end
  #
  #   # In controller:
  #   @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
  #   if @form.valid?
  #     User.create!(@form.attributes)
  #     redirect_to user_path
  #   else
  #     render :new
  #   end
  #
  #   # In view:
  #   <%= form_with model: @form, url: users_path do |f| %>
  #     <%= f.text_field :name %>
  #     <%= f.text_field :email %>
  #   <% end %>
  class Params
    include ActiveModel::Model
    include ActiveModel::Attributes

    # @rbs @errors: ::StructuredParams::Errors?

    class << self
      # @rbs self.@structured_attributes: Hash[Symbol, singleton(::StructuredParams::Params)]?
      # @rbs self.@model_name: ::ActiveModel::Name?

      # Override model_name for form helpers
      # By default, removes "Parameters", "Parameter", or "Form" suffix from class name
      # This allows the class to work seamlessly with Rails form helpers
      #
      # Example:
      #   UserRegistrationForm.model_name.name       # => "UserRegistration"
      #   UserRegistrationForm.model_name.param_key  # => "user_registration"
      #   UserParameters.model_name.name             # => "User"
      #   Admin::UserForm.model_name.name            # => "Admin::User"
      #: () -> ::ActiveModel::Name
      def model_name
        @model_name ||= begin
          namespace = module_parents.detect { |n| n.respond_to?(:use_relative_model_naming?) }
          # Remove suffix from the full class name (preserving namespace)
          name_without_suffix = name.sub(/(Parameters?|Form)$/, '')
          ActiveModel::Name.new(self, namespace, name_without_suffix)
        end
      end

      # Generate permitted parameter structure for Strong Parameters
      #: () -> Array[untyped]
      def permit_attribute_names
        attribute_types.map do |name, type|
          name = name.to_sym

          if type.is_a?(Type::Object) || type.is_a?(Type::Array)
            { name => type.permit_attribute_names }
          else
            name
          end
        end
      end

      # Permit parameters with optional require
      #
      # For Form Objects (with require):
      #   UserRegistrationForm.permit(params)
      #   # equivalent to:
      #   params.require(:user_registration).permit(UserRegistrationForm.permit_attribute_names)
      #
      # For API requests (without require):
      #   UserParams.permit(params, require: false)
      #   # equivalent to:
      #   params.permit(UserParams.permit_attribute_names)
      #
      #: (ActionController::Parameters params, ?require: bool) -> ActionController::Parameters
      def permit(params, require: true)
        if require
          key = model_name.param_key.to_sym
          params.require(key).permit(permit_attribute_names)
        else
          params.permit(permit_attribute_names)
        end
      end

      # Get structured attributes and their classes
      #: () -> Hash[Symbol, singleton(::StructuredParams::Params)]
      def structured_attributes
        @structured_attributes ||= attribute_types.each_with_object({}) do |(name, type), hash|
          next unless structured_params_type?(type)

          hash[name] = if type.is_a?(Type::Array)
                         type.item_type.value_class
                       else
                         type.value_class
                       end
        end
      end

      private

      # Determine if the specified type is a StructuredParams type
      #: (ActiveModel::Type::Value) -> bool
      def structured_params_type?(type)
        type.is_a?(Type::Object) ||
          (type.is_a?(Type::Array) && type.item_type_is_structured_params_object?)
      end
    end

    # Integrate validation of structured objects
    validate :validate_structured_parameters

    #: (Hash[untyped, untyped]|::ActionController::Parameters) -> void
    def initialize(params)
      processed_params = process_input_parameters(params)
      super(**processed_params)
    end

    #: () -> ::StructuredParams::Errors
    def errors
      @errors ||= Errors.new(self)
    end

    # ========================================
    # Form object support methods
    # These methods enable integration with Rails form helpers (form_with, form_for)
    # ========================================

    # Indicates whether the form object has been persisted to database
    # Always returns false for parameter/form objects
    #: () -> bool
    def persisted?
      false
    end

    # Returns the primary key value for the model
    # Always returns nil for parameter/form objects
    #: () -> nil
    def to_key
      nil
    end

    # Returns self for form helpers
    # Required by Rails form helpers to get the model object
    #: () -> self
    def to_model
      self
    end

    # Convert structured objects to Hash and get attributes
    #: (?symbolize: false, ?compact_mode: :none | :nil_only | :all_blank) -> Hash[String, untyped]
    #: (?symbolize: true, ?compact_mode: :none | :nil_only | :all_blank) -> Hash[Symbol, untyped]
    def attributes(symbolize: false, compact_mode: :none)
      attrs = super()

      self.class.structured_attributes.each_key do |name|
        value = attrs[name.to_s]
        attrs[name.to_s] = serialize_structured_value(value, compact_mode: compact_mode)
      end

      result = symbolize ? attrs.deep_symbolize_keys : attrs

      case compact_mode
      when :all_blank
        result.compact_blank
      when :nil_only
        result.compact
      else
        result
      end
    end

    private

    # Process input parameters
    #: (untyped) -> Hash[untyped, untyped]
    def process_input_parameters(params)
      case params
      when ActionController::Parameters
        self.class.permit(params, require: false).to_h
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
      self.class.structured_attributes.each_key do |name|
        value = attribute(name)
        next if value.blank?

        case value
        when Array
          validate_structured_array(name, value)
        else
          validate_structured_object(name, value)
        end
      end
    end

    # Validate structured arrays
    #: (Symbol, Array[untyped]) -> void
    def validate_structured_array(attr_name, array_value)
      array_value.each_with_index do |item, index|
        next if item.valid?(validation_context)

        error_path = format_error_path(attr_name, index)
        import_structured_errors(item.errors, error_path)
      end
    end

    # Validate structured objects
    #: (Symbol, StructuredParams::Params) -> void
    def validate_structured_object(attr_name, object_value)
      return if object_value.valid?(validation_context)

      error_path = format_error_path(attr_name, nil)
      import_structured_errors(object_value.errors, error_path)
    end

    # Format error path using dot notation (always consistent)
    #: (Symbol, Integer?) -> String
    def format_error_path(attr_name, index = nil)
      path_parts = [attr_name]
      path_parts << index.to_s if index
      path_parts.join('.')
    end

    # Serialize structured values
    #: (untyped, ?compact_mode: :none | :nil_only | :all_blank) -> untyped
    def serialize_structured_value(value, compact_mode: :none)
      case value
      when Array
        result = value.map { |item| item.attributes(symbolize: false, compact_mode: compact_mode) }

        case compact_mode
        when :all_blank
          result.compact_blank
        when :nil_only
          result.compact
        else
          result
        end
      when StructuredParams::Params
        value.attributes(symbolize: false, compact_mode: compact_mode)
      else
        value
      end
    end

    # Integrate structured parameter errors into parent errors
    #: (untyped, String) -> void
    def import_structured_errors(structured_errors, prefix)
      structured_errors.each do |error|
        # Create dotted attribute path and import normally
        error_attribute = "#{prefix}.#{error.attribute}"
        errors.import(error, attribute: error_attribute.to_sym)
      end
    end
  end
end
