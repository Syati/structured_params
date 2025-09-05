# rbs_inline: enabled
# frozen_string_literal: true

require 'active_model'
require 'active_model/type'
require 'action_controller/metal/strong_parameters'

# version
require_relative 'structured_params/version'

# errors
require_relative 'structured_params/errors'

# types (load first for module definition)
require_relative 'structured_params/type/object'
require_relative 'structured_params/type/array'

# params (load after type definitions)
require_relative 'structured_params/params'

# Main module
module StructuredParams
  # Helper method to register types
  #: () -> void
  def self.register_types
    ActiveModel::Type.register(:object, StructuredParams::Type::Object)
    ActiveModel::Type.register(:array, StructuredParams::Type::Array)
  end

  # Helper method to register types with custom names
  #: (object_name: Symbol, array_name: Symbol) -> void
  def self.register_types_as(object_name:, array_name:)
    ActiveModel::Type.register(object_name, StructuredParams::Type::Object)
    ActiveModel::Type.register(array_name, StructuredParams::Type::Array)
  end
end
