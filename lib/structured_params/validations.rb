# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Provides +validates_raw+ which validates raw parameter values before type casting.
  #
  # Internally delegates to ActiveModel's +validates+ on the +_before_type_cast+
  # attribute, then remaps errors back to the original attribute name.
  # This means all standard ActiveModel validators (format, numericality, etc.)
  # work as-is on the raw input value.
  #
  # Example:
  #   class UserParams < StructuredParams::Params
  #     attribute :age, :integer
  #     validates_raw :age, format: { with: /\A\d+\z/, message: 'must be numeric string' }
  #   end
  #
  #   params = UserParams.new(age: "abc")
  #   params.valid?            # => false
  #   params.errors[:age]      # => ["must be numeric string"]
  module Validations
    extend ActiveSupport::Concern

    included do
      class_attribute :validates_raw_btc_map, instance_accessor: false, default: {}
      class_attribute :validates_raw_remap_validator_installed, instance_accessor: false, default: false
    end

    class_methods do
      # Validates raw attribute value before type casting.
      #
      # Accepts the same options as +validates+ (format, numericality, presence, etc.),
      # but validates the raw input value before it is converted by ActiveModel::Attributes.
      #
      # Examples:
      #   validates_raw :age,   format: { with: /\A\d+\z/ }
      #   validates_raw :score, numericality: { only_integer: true }
      #   validates_raw :code,  format: { with: /\A[A-Z]+\z/, message: 'must be uppercase' }
      #
      #: (*Symbol, **untyped) -> void
      def validates_raw(*attr_names, **options)
        btc_map = attr_names.to_h { |attr| [attr.to_sym, :"#{attr}_before_type_cast"] }
        validates(*btc_map.values, **options)
        self.validates_raw_btc_map = validates_raw_btc_map.merge(btc_map)
        validates_raw_install_remap_validator_once
      end

      #: () -> void
      def validates_raw_install_remap_validator_once
        return if validates_raw_remap_validator_installed

        set_callback(:validate, :after, :validates_raw_remap_errors)

        self.validates_raw_remap_validator_installed = true
      end
      private :validates_raw_install_remap_validator_once
    end

    private

    #: () -> void
    def validates_raw_remap_errors
      self.class.validates_raw_btc_map.each do |attr, btc|
        next if errors.where(btc).none?

        errors.where(btc).dup.each { |e| errors.add(attr, e.message) }
        errors.delete(btc)
      end
    end
  end
end
