# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Extends ActiveModel::Attributes to define +attr_before_type_cast+ accessors
  # for each attribute, mirroring ActiveRecord::AttributeMethods::BeforeTypeCast.
  #
  # Example:
  #   class UserParams < StructuredParams::Params
  #     attribute :age, :integer
  #   end
  #
  #   params = UserParams.new(age: "42abc")
  #   params.age                    # => 42  (type-cast)
  #   params.age_before_type_cast   # => "42abc"  (raw input)
  module AttributeMethods
    extend ActiveSupport::Concern

    included do
      # Override attribute to also define `attr_before_type_cast`
      # via ActiveModel::Attribute#value_before_type_cast
      #: (Symbol name, *untyped) -> void
      def self.attribute(name, ...)
        super
        define_method(:"#{name}_before_type_cast") { @attributes[name.to_s].value_before_type_cast }
      end
    end
  end
end
