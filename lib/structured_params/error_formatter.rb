# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Error formatting functionality for StructuredParams
  # Provides methods to format error messages in different formats
  module ErrorFormatter
    extend ActiveSupport::Concern

    # Get error messages with JSON Pointer keys
    #: () -> Hash[String, Array[String]]
    def messages_with_json_pointer_keys
      errors.to_hash.transform_keys { |key| to_json_pointer(key.to_s) }
    end

    # Get full error messages with JSON Pointer keys
    #: () -> Hash[String, String]
    def full_messages_with_json_pointer_keys
      messages_with_json_pointer_keys.transform_values do |messages|
        messages.map { |message| humanize_error_key(message) }.join(', ')
      end
    end

    private

    # Convert any attribute key to JSON Pointer format
    # This is a general utility method that can be used for any key conversion
    #: (String | Symbol) -> String
    def to_json_pointer(key)
      "/#{key.to_s.gsub('.', '/')}"
    end

    # Convert JSON Pointer back to dot notation
    #: (String) -> String
    def from_json_pointer(pointer)
      pointer.sub(%r{^/}, '').gsub('/', '.')
    end

    # Check if a string is a valid JSON Pointer
    #: (String) -> bool
    def json_pointer?(string)
      string.start_with?('/')
    end

    # Convert attribute key to JSON Pointer format (kept for backward compatibility)
    #: (String) -> String
    def attribute_key_to_json_pointer(attribute_key)
      to_json_pointer(attribute_key)
    end

    # Humanize error key for better display
    #: (String) -> String
    def humanize_error_key(message)
      message.humanize
    end
  end
end
