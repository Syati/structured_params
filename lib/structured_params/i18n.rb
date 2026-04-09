# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  # Provides i18n-aware human_attribute_name resolution for nested dot-notation
  # attributes (e.g. "hobbies.0.name").
  #
  # When included in a Params subclass, overrides +human_attribute_name+ so that
  # each segment of the path is resolved by the corresponding nested model class,
  # ensuring that child-model translations are respected instead of falling back
  # to the parent model's i18n context.
  #
  # == i18n keys
  #
  # You can customize how array indices and object nesting are rendered by
  # defining the following keys in your locale file:
  #
  #   ja:
  #     activemodel:
  #       errors:
  #         nested_attribute:
  #           array:  "%{parent} %{index} 番目の%{child}"
  #           object: "%{parent}の%{child}"
  #
  # Without these keys the defaults are:
  #   array  → "<parent> <index> <child>"   (e.g. "Hobbies 0 Name")
  #   object → "<parent> <child>"           (e.g. "Address Postal code")
  module I18n
    extend ActiveSupport::Concern

    class_methods do # rubocop:disable Metrics/BlockLength
      # Override human_attribute_name to resolve nested dot-notation paths.
      #
      # Flat attributes (no dot) are delegated to the default ActiveModel
      # behaviour unchanged.
      #
      # Example (en default):
      #   human_attribute_name(:'hobbies.0.name') # => "Hobbies 0 Name"
      #
      # Example with i18n (ja):
      #   human_attribute_name(:'hobbies.0.name') # => "趣味 0 番目の名前"
      #
      #: (Symbol | String, ?Hash[untyped, untyped]) -> String
      def human_attribute_name(attribute, options = {})
        parts = attribute.to_s.split('.')
        return super if parts.length == 1
        return super unless structured_attributes.key?(parts.first)

        resolve_nested_human_attribute_name(parts, options)
      end

      private

      # Walk +parts+ (e.g. ["hobbies", "0", "name"]) and build a human-readable
      # label by delegating each segment to the appropriate nested class.
      #
      # Only +:locale+ is forwarded to inner +human_attribute_name+ calls.
      # Options such as +:default+ are specific to the outer call (e.g. from
      # +full_messages+) and must not bleed into individual segment lookups,
      # where they would replace the segment's own translation fallback.
      #
      #: (Array[String], Hash[untyped, untyped]) -> String
      def resolve_nested_human_attribute_name(parts, options)
        label = nil
        klass = self
        inner_opts = options.slice(:locale)

        attr_segments(parts).each do |index, attr|
          human = klass&.human_attribute_name(attr, inner_opts) || attr.humanize
          label = build_nested_label(label, index, human, options)
          klass &&= klass.structured_attributes[attr]
        end

        label || parts.last.humanize
      end

      # Convert a parts array into (index_or_nil, attr) pairs.
      #
      #   attr_segments(["hobbies", "0", "name"]) #=> [[nil, "hobbies"], ["0", "name"]]
      #   attr_segments(["address", "postal_code"]) #=> [[nil, "address"], [nil, "postal_code"]]
      #
      #: (Array[String]) -> Array[[String?, String]]
      def attr_segments(parts)
        index = nil
        parts.each_with_object([]) do |part, segments|
          if part.match?(/\A\d+\z/)
            index = part
          else
            segments << [index, part]
            index = nil
          end
        end
      end

      # Combine +result+ (accumulated label so far), an optional array +index+,
      # and the new +attr_human+ into a single label string.
      #
      # Uses the i18n keys:
      #   activemodel.errors.nested_attribute.array  (parent, index, child)
      #   activemodel.errors.nested_attribute.object (parent, child)
      #
      # The +locale:+ key from +options+ is forwarded to ::I18n.t so that an
      # explicit locale passed to human_attribute_name is honoured.
      #
      #: (String?, String?, String, Hash[untyped, untyped]) -> String
      def build_nested_label(result, index, attr_human, options)
        return attr_human if result.nil?

        i18n_opts = options.slice(:locale)

        if index
          ::I18n.t(
            'activemodel.errors.nested_attribute.array',
            parent: result,
            index: index,
            child: attr_human,
            default: "#{result} #{index} #{attr_human}",
            **i18n_opts
          )
        else
          ::I18n.t(
            'activemodel.errors.nested_attribute.object',
            parent: result,
            child: attr_human,
            default: "#{result} #{attr_human}",
            **i18n_opts
          )
        end
      end
    end
  end
end
