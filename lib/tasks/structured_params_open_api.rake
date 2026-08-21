# rbs_inline: enabled
# frozen_string_literal: true

namespace :structured_params do
  namespace :openapi do
    desc 'Check registered and auto-discovered StructuredParams classes against the OpenAPI document'
    task drift_check: :environment do
      Rails.application.eager_load! if defined?(Rails) && Rails.respond_to?(:application)
      StructuredParams::OpenApi::Registry.check_all!(auto_discover: true)
    end
  end
end
