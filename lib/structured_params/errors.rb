# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Custom errors collection that handles nested attribute names
  class Errors < ActiveModel::Errors
    # Override to_hash to provide nested structure for dot-notation attributes
    # This maintains compatibility with ActiveModel::Errors while adding nested functionality
    # rubocop:disable Style/OptionalBooleanParameter
    #: (?bool) -> Hash[String, String]
    def to_hash(full_messages = false)
      message_method = full_messages ? :full_message : :message

      # Group errors by attribute and convert to messages
      group_by_attribute.each_with_object({}) do |(attribute, error_list), result|
        build_nested_hash(result, [[attribute, error_list.map(&message_method)]].to_h)
      end
    end
    # rubocop:enable Style/OptionalBooleanParameter

    private

    # Build a nested hash structure from flat dot-notation keys
    # Converts "address.postal_code" to {address: {postal_code: value}}
    #: (Hash[untyped, untyped], Hash[Symbol, untyped], ?String) -> Hash[String, String]
    def build_nested_hash(target_hash, flat_hash, separator = '.')
      flat_hash.each_with_object(target_hash) do |(key, value), result|
        *prefix, last = key.to_s.split(separator)
        # Navigate/create nested structure
        prefix.reduce(result) do |hash, k|
          hash[k] ||= {}
        end[last] = value
      end
    end
  end
end
