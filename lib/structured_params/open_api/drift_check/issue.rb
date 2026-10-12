# rbs_inline: enabled
# frozen_string_literal: true

module StructuredParams
  module OpenApi
    class DriftCheck
      # A single finding (error, skipped check, or ignored finding) from a drift check.
      Issue = Struct.new(
        :kind,     #: Symbol
        :path,     #: String
        :message,  #: String
        keyword_init: true
      )
    end
  end
end
