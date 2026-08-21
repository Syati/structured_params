# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::OpenApi::Registry do
  after do
    described_class.clear
    StructuredParams::OpenApi.reset_configuration!
  end

  it 'runs registered checks and raises when any of them drift' do
    parameter_class = Class.new(StructuredParams::Params) { attribute :name, :string }
    schema = { 'type' => 'object', 'properties' => { 'age' => { 'type' => 'integer' } } }
    described_class.register(parameter_class, schema: schema)

    expect { described_class.check_all! }.to raise_error(StructuredParams::OpenApi::DriftError, /drift detected/)
  end

  context 'with an auto-discovery filter' do
    let(:parameter_class) do
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
      StructuredParams::OpenApi.configure do |config|
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
end
