# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Custom errors collection that handles nested attribute names
  class Errors < ActiveModel::Errors
    # Override to_hash to maintain compatibility with ActiveModel::Errors by default
    # Add structured option to get nested structure for dot-notation attributes
    # rubocop:disable Style/OptionalBooleanParameter
    #: (?bool, ?structured: false) -> Hash[Symbol, String]
    #: (?bool, structured: true) -> Hash[Symbol, untyped]
    def to_hash(full_messages = false, structured: false)
      if structured
        message_method = full_messages ? :full_message : :message

        # Group errors by attribute and convert to messages
        group_by_attribute.each_with_object({}) do |(attribute, error_list), result|
          build_nested_hash(result, [[attribute, error_list.map(&message_method)]].to_h)
        end
      else
        # Use default ActiveModel::Errors behavior
        super(full_messages)
      end
    end
    # rubocop:enable Style/OptionalBooleanParameter

    private

    # Build a nested hash structure from flat dot-notation keys
    # Converts "address.postal_code" to {address: {postal_code: value}}
    #: (Hash[untyped, untyped], Hash[Symbol, Array[String]], ?String) -> Hash[Symbol, untyped]
    def build_nested_hash(target_hash, flat_hash, separator = '.')
      flat_hash.each_with_object(target_hash) do |(key, value), result|
        *prefix, last = key.to_s.split(separator)
        # Navigate/create nested structure and use symbols for keys
        prefix.reduce(result) do |hash, k|
          hash[k.to_sym] ||= {}
        end[last.to_sym] = value
      end
    end
  end
end
