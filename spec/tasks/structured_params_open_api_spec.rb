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

  context 'when every check passes' do
    before do
      described_class.define_task(:environment)
      parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
      schema = { 'type' => 'object', 'properties' => { 'name' => { 'type' => %w[string integer] } } }
      StructuredParams::OpenApi::Registry.register(parameter_class, schema: schema)
    end

    it 'prints skipped checks without failing' do
      expect { drift_check_task.invoke }.to output(/OpenAPI checks skipped.*Checked 1 classes/m).to_stdout
    end

    it 'fails on skipped checks when STRUCTURED_PARAMS_STRICT=1' do
      stub_const('ENV', ENV.to_hash.merge('STRUCTURED_PARAMS_STRICT' => '1'))

      expect { drift_check_task.invoke }.to raise_error(StructuredParams::OpenApi::DriftError, /checks skipped/)
    end
  end

  it 'eager loads the Rails application before checking' do
    described_class.define_task(:environment)
    application = double(eager_load!: nil)
    stub_const('Rails', Module.new)
    allow(Rails).to receive(:application).and_return(application)

    expect { drift_check_task.invoke }.to output(/No parameter classes were checked/).to_stdout
    expect(application).to have_received(:eager_load!)
  end
end
