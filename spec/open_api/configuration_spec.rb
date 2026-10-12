# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'fileutils'

RSpec.describe StructuredParams::OpenApi::Configuration do
  after { StructuredParams::OpenApi.reset_configuration! }

  let(:parameter_class) do
    stub_const('OpenApiRequestParams', Class.new(StructuredParams::Params)).tap do |klass|
      klass.attribute :name, :string
      klass.validates :name, presence: true
    end
  end

  let(:document) do
    {
      'components' => {
        'schemas' => {
          'OpenApiRequest' => {
            'type' => 'object',
            'properties' => { 'name' => { 'type' => 'string' } },
            'required' => ['name']
          }
        }
      }
    }
  end

  it 'uses the configured document and default class-name convention' do
    StructuredParams::OpenApi.configure { |config| config.document = document }

    result = StructuredParams::OpenApi::DriftCheck.call(parameter_class: parameter_class)

    expect(result).to be_valid
  end

  it 'discovers only classes selected by the configured filter' do
    stub_const('Api', Module.new)
    parameter_class = stub_const('Api::CreateUserParams', Class.new(StructuredParams::Params))
    StructuredParams::OpenApi.configure do |config|
      config.parameter_class_filter = ->(klass) { klass.name&.start_with?('Api::') }
    end

    expect(StructuredParams::OpenApi.configuration.parameter_classes).to include(parameter_class)
  end

  describe '#ignore_drift and #ignored?' do
    it 'matches only the given kind at the given path when kind is specified' do
      StructuredParams::OpenApi.configure do |config|
        config.ignore_drift(path: 'wallet_information.wallet_type', kind: :missing_presence_validation)
      end

      expect(StructuredParams::OpenApi.configuration.ignored?(:missing_presence_validation,
                                                              'wallet_information.wallet_type')).to be true
      expect(StructuredParams::OpenApi.configuration.ignored?(:type_mismatch,
                                                              'wallet_information.wallet_type')).to be false
      expect(StructuredParams::OpenApi.configuration.ignored?(:missing_presence_validation, 'other_path')).to be false
    end

    it 'matches every kind at the path when kind is omitted' do
      StructuredParams::OpenApi.configure { |config| config.ignore_drift(path: 'legacy_field') }

      expect(StructuredParams::OpenApi.configuration.ignored?(:type_mismatch, 'legacy_field')).to be true
      expect(StructuredParams::OpenApi.configuration.ignored?(:missing_attribute, 'legacy_field')).to be true
    end
  end

  describe '#ignore_drift' do
    it 'rejects an unknown kind so a typo cannot silently never match' do
      expect { StructuredParams::OpenApi.configuration.ignore_drift(path: 'a', kind: :type_mismtach) }
        .to raise_error(ArgumentError, /unknown kind/)
    end

    it 'scopes a rule to the given parameter class' do
      configuration = StructuredParams::OpenApi.configuration
      configuration.ignore_drift(path: 'a', parameter_class: 'ScopedParams')

      expect(configuration.ignored?(:type_mismatch, 'a', 'ScopedParams')).to be true
      expect(configuration.ignored?(:type_mismatch, 'a', 'OtherParams')).to be false
      expect(configuration.ignored?(:type_mismatch, 'a')).to be false
    end
  end

  describe '#pointer_for' do
    subject(:configuration) { described_class.new }

    it 'maps class names to component pointers by the default convention' do
      expect(configuration.pointer_for(stub_const('Api::UserParams', Class.new))).to eq('/components/schemas/User')
      expect(configuration.pointer_for(stub_const('CreateUserForm', Class.new))).to eq('/components/schemas/CreateUser')
      expect(configuration.pointer_for(stub_const('Plain', Class.new))).to eq('/components/schemas/Plain')
    end

    it 'passes JSON Pointers through and escapes component names' do
      expect(configuration.pointer_for(Class.new, '/paths/x')).to eq('/paths/x')
      expect(configuration.pointer_for(Class.new, '#/paths/x')).to eq('#/paths/x')
      expect(configuration.pointer_for(Class.new, 'a/b~c')).to eq('/components/schemas/a~1b~0c')
    end

    it 'uses a custom schema_name_resolver' do
      configuration.schema_name_resolver = ->(klass) { "#{klass.name}Request" }

      expect(configuration.pointer_for(stub_const('Thing', Class.new))).to eq('/components/schemas/ThingRequest')
    end
  end

  describe '#parameter_classes' do
    it 'is empty without a filter and ignores anonymous classes' do
      configuration = described_class.new
      expect(configuration.parameter_classes).to eq([])

      Class.new(StructuredParams::Params)
      configuration.parameter_class_filter = ->(klass) { klass.name.start_with?('Api::') }

      expect { configuration.parameter_classes }.not_to raise_error
    end
  end

  describe '#load_document' do
    subject(:configuration) { described_class.new }

    it 'parses a file once per modification time' do
      Tempfile.create(['openapi', '.yml']) do |file|
        file.write("a: 1\n")
        file.flush
        allow(YAML).to receive(:safe_load_file).and_call_original

        2.times { configuration.load_document(file.path) }
        expect(YAML).to have_received(:safe_load_file).once

        file.write("b: 2\n")
        file.flush
        FileUtils.touch(file.path, mtime: Time.now + 5)
        expect(configuration.load_document(file.path)).to eq('a' => 1, 'b' => 2)
      end
    end

    it 'resolves YAML aliases and rejects a document that is not a mapping' do
      Tempfile.create(['openapi', '.yml']) do |file|
        file.write("base: &base\n  a: 1\ncopy: *base\n")
        file.flush
        expect(configuration.load_document(file.path)['copy']).to eq('a' => 1)
      end

      Tempfile.create(['empty', '.yml']) do |file|
        expect { configuration.load_document(file.path) }.to raise_error(ArgumentError, /mapping/)
      end
    end

    it 'raises for a missing file' do
      expect { configuration.load_document('/nonexistent/openapi.yml') }.to raise_error(Errno::ENOENT)
    end
  end
end
