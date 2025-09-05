# rbs_inline: enabled
# frozen_string_literal: true

# rubocop:disable Style/OptionalBooleanParameter
module StructuredParams
  # Custom errors collection that handles nested attribute names
  class Errors < ActiveModel::Errors
    # Override to_hash to maintain compatibility with ActiveModel::Errors by default
    # Add structured option to get nested structure for dot-notation attributes
    #: (?bool, ?structured: false) -> Hash[Symbol, String]
    #: (?bool, structured: bool) -> Hash[Symbol, untyped]
    def to_hash(full_messages = false, structured: false)
      if structured
        attribute_messages_hash = build_attribute_messages_hash(full_messages)
        build_nested_hash({}, attribute_messages_hash)
      else
        # Use default ActiveModel::Errors behavior
        super(full_messages)
      end
    end

    # Override as_json to support structured option
    # This maintains compatibility with ActiveModel::Errors while adding structured functionality
    #: (?{ full_messages?: bool, structured?: bool }?) -> Hash[Symbol, untyped]
    def as_json(options = nil)
      options ||= {}
      to_hash(options.fetch(:full_messages, false),
              structured: options.fetch(:structured, false))
    end

    # Override messages to support structured option
    # This maintains compatibility with ActiveModel::Errors while adding structured functionality
    #: (?structured: bool) -> Hash[Symbol, untyped]
    def messages(structured: false)
      hash = to_hash(false, structured: structured)
      hash.default = [].freeze
      hash.freeze
      hash
    end

    private

    # Build a hash with attribute names as keys and their error messages as values
    # This is used for to_hash(structured: true)
    #: (bool) -> Hash[Symbol, Array[String]]
    def build_attribute_messages_hash(full_messages = false)
      message_method = full_messages ? :full_message : :message

      group_by_attribute.transform_values do |error_list|
        error_list.map(&message_method)
      end
    end

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
# rubocop:enable Style/OptionalBooleanParameter
