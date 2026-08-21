# frozen_string_literal: true

require 'spec_helper'
require 'rake'

RSpec.describe Rake::Task do
  subject(:drift_check_task) { described_class['structured_params:openapi:drift_check'] }

  around do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new
    load File.expand_path('../../lib/tasks/structured_params_open_api.rake', __dir__)
    example.run
  ensure
    Rake.application = original_application
  end

  after { StructuredParams::OpenApi::Registry.clear }

  it 'runs all registered drift checks after the Rails environment task' do
    described_class.define_task(:environment)
    parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
    schema = { 'type' => 'object', 'properties' => { 'age' => { 'type' => 'integer' } } }
    StructuredParams::OpenApi::Registry.register(parameter_class, schema: schema)

    expect { drift_check_task.invoke }
      .to raise_error(StructuredParams::OpenApi::DriftError, /drift detected/)
  end
end
