# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Form object behavior layered onto Params subclasses.
  module FormObject
    extend ActiveSupport::Concern

    # Form object support for Rails helpers.
    #: () -> bool
    def persisted?
      false
    end

    #: () -> nil
    def to_key
      nil
    end

    #: () -> self
    def to_model
      self
    end

    private

    # Whether to call params.require(param_key) before permitting.
    #
    # Only ever true for Form-suffixed classes (form_class?); non-Form
    # Params/Parameters subclasses always permit the top level directly.
    #: (ActionController::Parameters) -> bool
    def require_nested_parameters?(params)
      return false unless self.class.form_class?
      return true if matches_model_name?(params)
      return false if params.permitted?
      return false if flat_parameters?(params)

      true
    end

    #: (ActionController::Parameters) -> bool
    def matches_model_name?(params)
      key = self.class.model_name.param_key
      return false unless params.key?(key)

      params[key].is_a?(ActionController::Parameters)
    end

    # Only treat params as already-flat attributes when none of the top-level
    # values are themselves nested. A nested value under some other key means
    # the request shape is ambiguous, so we fall through to raising
    # ParameterMissing instead of silently guessing which keys belong here.
    #: (ActionController::Parameters) -> bool
    def flat_parameters?(params)
      return false if params.values.any?(ActionController::Parameters)

      attribute_keys_present?(params)
    end

    #: (ActionController::Parameters) -> bool
    def attribute_keys_present?(params)
      params.keys.any? { |key| self.class.attribute_types.key?(key.to_s) }
    end
  end
end
