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

target :openapi do
  signature 'sig', 'structured_params-openapi/sig'

  check 'structured_params-openapi/lib'

  configure_code_diagnostics do |hash|
    hash[Steep::Diagnostic::Ruby::LibraryRBSError] = nil
  end
end
