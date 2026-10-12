# rbs_inline: enabled
# frozen_string_literal: true

namespace :structured_params do
  namespace :openapi do
    desc 'Check registered and auto-discovered StructuredParams classes against the OpenAPI document'
    task drift_check: :environment do
      Rails.application&.eager_load! if defined?(Rails) && Rails.respond_to?(:application)
      registry = StructuredParams::OpenAPI::Registry
      # Set STRUCTURED_PARAMS_STRICT=1 to fail the task when any check was skipped.
      results = registry.check_all!(auto_discover: true, strict: ENV['STRUCTURED_PARAMS_STRICT'] == '1')
      puts registry.report(results)
    end
  end
end
