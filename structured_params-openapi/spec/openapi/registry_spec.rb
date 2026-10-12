# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::OpenAPI::Registry do
  after do
    described_class.clear
    StructuredParams::OpenAPI.reset_configuration!
  end

  it 'runs registered checks and raises when any of them drift' do
    parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
    schema = { 'type' => 'object', 'properties' => { 'age' => { 'type' => 'integer' } } }
    described_class.register(parameter_class, schema: schema)

    expect { described_class.check_all! }.to raise_error(StructuredParams::OpenAPI::DriftError, /drift detected/)
  end

  context 'with an auto-discovery filter' do
    let!(:parameter_class) do
      stub_const('Api', Module.new)
      stub_const('Api::CreateUserParams', Class.new(StructuredParams::Params)).tap do |klass|
        klass.attribute :name, :string
        klass.validates :name, presence: true
      end
    end

    before do
      document = {
        'components' => {
          'schemas' => {
            'CreateUser' => {
              'type' => 'object',
              'properties' => { 'name' => { 'type' => 'string' } },
              'required' => ['name']
            }
          }
        }
      }
      StructuredParams::OpenAPI.configure do |config|
        config.document = document
        config.parameter_class_filter = ->(klass) { klass.equal?(parameter_class) }
      end
    end

    it 'auto-discovers parameter classes selected by the configured filter' do
      results = described_class.check_all(auto_discover: true)

      expect(results).to all(be_valid)
      expect(results).to have_attributes(size: 1)
    end
  end

  it 'resolves a class-name String registered before autoloading has run' do
    stub_const('Api', Module.new)
    stub_const('Api::CreateUserParams', Class.new(StructuredParams::Params)).tap do |klass|
      klass.attribute :name, :string
    end
    schema = { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } } }
    described_class.register('Api::CreateUserParams', schema: schema)

    results = described_class.check_all

    expect(results).to all(be_valid)
  end

  describe 'skipped and ignored checks' do
    let(:parameter_class) { Class.new(StructuredParams::Params) { attribute :name, :string } }
    let(:skipping_schema) do
      { 'type' => 'object', 'properties' => { 'name' => { 'type' => %w[string integer] } } }
    end

    before { described_class.register(parameter_class, schema: skipping_schema) }

    it 'does not raise for a skipped-only result but reports it' do
      results = described_class.check_all!

      expect(results).to all(be_valid)
      expect(described_class.report(results)).to include('OpenAPI checks skipped', 'name', 'with skipped checks')
    end

    it 'raises for a skipped-only result in strict mode' do
      expect { described_class.check_all!(strict: true) }
        .to raise_error(StructuredParams::OpenAPI::DriftError, /checks skipped/)
    end

    it 'includes skips in the message when the class also has errors' do
      skipping_schema['properties']['age'] = { 'type' => 'integer' }

      expect { described_class.check_all! }
        .to raise_error(StructuredParams::OpenAPI::DriftError, /drift detected.*checks skipped/m)
    end

    it 'joins the messages of every failing class' do
      other = Class.new(StructuredParams::Params) { attribute :id, :integer }
      described_class.register(other, schema: { 'type' => 'object', 'properties' => { 'x' => { 'type' => 'string' } } })
      skipping_schema['properties']['age'] = { 'type' => 'integer' }

      expect { described_class.check_all! }
        .to raise_error(StructuredParams::OpenAPI::DriftError) { |error| expect(error.message.scan('drift detected').size).to eq(2) }
    end
  end

  describe '.report' do
    it 'warns when nothing was checked and lists ignored findings' do
      expect(described_class.report([])).to include('No parameter classes were checked')

      parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
      StructuredParams::OpenAPI.configure { |config| config.ignore_drift(path: 'age') }
      described_class.register(parameter_class,
                               schema: { 'type' => 'object', 'properties' => { 'age' => { 'type' => 'integer' } } })

      report = described_class.report(described_class.check_all)

      expect(report).to include('OpenAPI findings ignored', 'age')
    end
  end

  it 'passes register options through to the check' do
    parameter_class = Class.new(StructuredParams::Params) { attribute :user_id, :integer }
    schema = { 'type' => 'object', 'properties' => { 'userId' => { 'type' => 'integer' } } }
    described_class.register(parameter_class, schema: schema, property_names: { user_id: 'userId' })

    expect(described_class.check_all).to all(be_valid)
  end

  it 'checks a class against its own OpenAPI document instead of the configured one' do
    parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
    other_document = { 'components' => { 'schemas' => { 'Admin' => {
      'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } }
    } } } }
    StructuredParams::OpenAPI.configure { |config| config.document = { 'components' => { 'schemas' => {} } } }
    described_class.register(parameter_class, openapi: other_document, schema: 'Admin')

    expect(described_class.check_all).to all(be_valid)
  end

  describe 'with a document_resolver' do
    def document_with(property)
      props = { property => { 'type' => 'string' } }
      { 'components' => { 'schemas' => { 'User' => { 'type' => 'object', 'properties' => props } } } }
    end

    it 'checks auto-discovered classes against the document chosen per class' do
      stub_const('AdminApi', Module.new)
      stub_const('FrontApi', Module.new)
      classes = { 'AdminApi::UserParams' => :role, 'FrontApi::UserParams' => :nickname }.map do |name, attribute|
        stub_const(name, Class.new(StructuredParams::Params)).tap { |klass| klass.attribute attribute, :string }
      end
      documents = { 'AdminApi::UserParams' => document_with('role'), 'FrontApi::UserParams' => document_with('nickname') }
      StructuredParams::OpenAPI.configure do |config|
        config.parameter_class_filter = ->(klass) { classes.include?(klass) }
        config.document_resolver = ->(klass) { documents.fetch(klass.name) }
      end

      results = described_class.check_all(auto_discover: true)

      expect(results.size).to eq(2)
      expect(results).to all(be_valid)
    end
  end
end
