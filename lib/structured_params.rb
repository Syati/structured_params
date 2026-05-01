# rbs_inline: enabled
# frozen_string_literal: true

require 'active_model'
require 'active_model/type'
require 'action_controller/metal/strong_parameters'

# version
require_relative 'structured_params/version'

# errors
require_relative 'structured_params/errors'
require_relative 'structured_params/attribute_methods'
require_relative 'structured_params/validations'
require_relative 'structured_params/i18n'

# types (load first for module definition)
require_relative 'structured_params/type/object'
require_relative 'structured_params/type/array'

# params (load after type definitions)
require_relative 'structured_params/params'

# Main module
module StructuredParams
  # Global configuration for StructuredParams.
  #
  # == Options
  #
  # +array_index_base+ (Integer, default: +0+)::
  #   Controls how array indices are displayed in human attribute names and
  #   error messages.
  #
  #   * +0+ – 0-based (raw Ruby index): "Hobbies 0 Name"
  #   * +1+ – 1-based (human-friendly): "Hobbies 1 Name"
  #
  # This setting applies to both API param error messages and Form Object
  # +full_messages+.
  #
  # == Example
  #
  #   # config/initializers/structured_params.rb
  #   StructuredParams.configure do |config|
  #     config.array_index_base = 1   # show "1st" instead of "0th" to users
  #   end
  #
  class Configuration
    attr_reader :array_index_base #: Integer

    #: () -> void
    def initialize
      @array_index_base = 0
    end

    #: (Integer) -> void
    def array_index_base=(value)
      raise ArgumentError, "array_index_base must be 0 or 1, got: #{value.inspect}" unless [0, 1].include?(value)

      @array_index_base = value
    end
  end

  class << self
    # @rbs self.@configuration: Configuration?

    #: () -> Configuration
    def configuration
      @configuration ||= Configuration.new
    end

    #: () { (Configuration) -> void } -> void
    def configure
      yield configuration
    end

    #: () -> void
    def reset_configuration!
      @configuration = Configuration.new
    end

    # Helper method to register types
    #: () -> void
    def register_types
      ActiveModel::Type.register(:object, StructuredParams::Type::Object)
      ActiveModel::Type.register(:array, StructuredParams::Type::Array)
    end

    # Helper method to register types with custom names
    #: (object_name: Symbol, array_name: Symbol) -> void
    def register_types_as(object_name:, array_name:)
      ActiveModel::Type.register(object_name, StructuredParams::Type::Object)
      ActiveModel::Type.register(array_name, StructuredParams::Type::Array)
    end
  end
end
