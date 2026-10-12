# rbs_inline: enabled
# frozen_string_literal: true

require 'structured_params'
require_relative 'openapi/version'
require_relative 'openapi/configuration'
require_relative 'openapi/drift_check'
require_relative 'openapi/registry'

module StructuredParams
  # OpenAPI drift check for StructuredParams classes.
  module OpenAPI
    RAKE_TASK_PATH = File.expand_path('../tasks/structured_params_openapi.rake', __dir__) #: String

    if defined?(Rails::Railtie)
      # Defers loading the drift-check rake task until Rails actually loads rake tasks,
      # so requiring this gem never depends on the Rake DSL being mixed into +main+
      # (e.g. `rails runner`, `rails console`, app boot).
      class Railtie < Rails::Railtie
        rake_tasks do
          load StructuredParams::OpenAPI::RAKE_TASK_PATH
        end
      end
    elsif defined?(Rake::DSL)
      load RAKE_TASK_PATH
    end
  end
end
