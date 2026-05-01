# frozen_string_literal: true
# rbs_inline: enabled

# D = Steep::Diagnostic
target :lib do
  signature 'sig'

  check 'lib'

  # Suppress errors from broken library RBS files in gem_rbs_collection
  configure_code_diagnostics do |hash|
    hash[Steep::Diagnostic::Ruby::LibraryRBSError] = nil
  end
end
