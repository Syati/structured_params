# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe StructuredParams::OpenApi::DriftCheck do
  describe '.call' do
    let(:schema) do
      {
        'type' => 'object',
        'properties' => {
          'name' => { 'type' => 'string' },
          'age' => { 'type' => 'integer' },
          'enabled' => { 'type' => 'boolean' },
          'tags' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
          'address' => {
            'type' => 'object',
            'properties' => { 'city' => { 'type' => 'string' } },
            'required' => ['city']
          }
        },
        'required' => %w[name age]
      }
    end

    let(:address_class) do
      Class.new(StructuredParams::Params) do
        attribute :city, :string
        validates :city, presence: true
      end
    end
    let(:parameter_class) do
      address = address_class
      Class.new(StructuredParams::Params) do
        attribute :name, :string
        attribute :age, :integer
        attribute :enabled, :boolean
        attribute :tags, :array, value_type: :string
        attribute :address, :object, value_class: address
        validates :name, :age, presence: true
      end
    end

    it 'accepts matching attributes, types, nested objects, and required validations' do
      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped).to be_empty
    end

    it 'reports missing and unexpected attributes, types, and required validations' do
      parameter_class.attribute :extra, :string
      parameter_class.attribute :age, :string
      parameter_class._validators[:age].clear

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result.errors.map(&:kind)).to contain_exactly(
        :unexpected_attribute,
        :type_mismatch,
        :missing_presence_validation
      )
      expect(result.to_message).to include('extra', 'schema type :integer does not match attribute type :string')
    end

    it 'moves a finding matching a configured Configuration#ignore rule to result.ignored' do
      parameter_class._validators[:age].clear
      StructuredParams::OpenApi.configure do |config|
        config.ignore_drift(path: 'age', kind: :missing_presence_validation)
      end

      begin
        result = described_class.call(schema: schema, parameter_class: parameter_class)
      ensure
        StructuredParams::OpenApi.reset_configuration!
      end

      expect(result).to be_valid
      expect(result.errors).to be_empty
      expect(result.ignored.map(&:path)).to contain_exactly('age')
    end

    it 'maps differently named schema properties to attributes' do
      schema['properties']['userId'] = schema['properties'].delete('name')
      schema['required'][0] = 'userId'

      result = described_class.call(
        schema: schema,
        parameter_class: parameter_class,
        property_names: { name: 'userId' }
      )

      expect(result).to be_valid
    end

    it 'reports union schemas as skipped instead of treating them as compatible' do
      schema['properties']['age'] = { 'oneOf' => [{ 'type' => 'integer' }, { 'type' => 'string' }] }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped.first.message).to include('oneOf')
    end

    it 'unwraps a single-entry allOf instead of treating it as unsupported composition' do
      # Generators such as TypeSpec commonly wrap a single $ref in allOf because
      # OpenAPI/JSON Schema forbid sibling keys (e.g. description) directly next to $ref.
      schema['properties']['age'] = { 'allOf' => [{ 'type' => 'string' }], 'description' => 'wrapped' }
      parameter_class.attribute :age, :string

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped).to be_empty
    end

    it 'still reports multi-entry allOf as skipped composition' do
      schema['properties']['age'] = { 'allOf' => [{ 'type' => 'integer' }, { 'minimum' => 0 }] }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped.first.message).to include('allOf')
    end

    it 'allows required validation checking to be disabled' do
      schema['required'] << 'enabled'

      result = described_class.call(
        schema: schema,
        parameter_class: parameter_class,
        required_validation: :none
      )

      expect(result).to be_valid
    end

    it 'loads a YAML schema selected by JSON Pointer and resolves local references' do
      address_schema = schema['properties'].delete('address')
      schema['properties']['address'] = { '$ref' => '#/components/schemas/Address' }
      document = { 'components' => { 'schemas' => { 'Request' => schema, 'Address' => address_schema } } }

      Tempfile.create(['openapi', '.yml']) do |file|
        file.write(document.to_yaml)
        file.flush

        result = described_class.call(
          openapi: file.path,
          schema: 'Request',
          parameter_class: parameter_class
        )

        expect(result).to be_valid
      end
    end

    it 'selects a schema from a hash with a JSON Pointer' do
      document = { 'components' => { 'schemas' => { 'Request' => schema } } }

      result = described_class.call(
        openapi: document,
        schema: 'Request',
        parameter_class: parameter_class
      )

      expect(result).to be_valid
    end

    it 'reports a missing schema as an error instead of raising' do
      document = { 'components' => { 'schemas' => { 'Other' => schema } } }

      result = described_class.call(openapi: document, schema: 'Missing', parameter_class: parameter_class)

      expect(result.errors).to contain_exactly(
        have_attributes(kind: :missing_schema, path: '(root)',
                        message: a_string_including('no matching OpenAPI schema'))
      )
    end

    it 'lets a missing schema be ignored for one class only' do
      document = { 'components' => { 'schemas' => { 'Other' => schema } } }
      StructuredParams::OpenApi.configure do |config|
        config.ignore_drift(path: '(root)', kind: :missing_schema, parameter_class: parameter_class)
      end

      result = described_class.call(openapi: document, schema: 'Missing', parameter_class: parameter_class)
      other = described_class.call(openapi: document, schema: 'Missing', parameter_class: Class.new(StructuredParams::Params))

      expect(result).to be_valid
      expect(result.ignored.map(&:kind)).to eq([:missing_schema])
      expect(other).not_to be_valid
    ensure
      StructuredParams::OpenApi.reset_configuration!
    end

    it 'reports a pointer that runs past the end of an array as a missing schema' do
      document = { 'items' => [schema] }

      result = described_class.call(openapi: document, schema: '/items/5', parameter_class: parameter_class)

      expect(result.errors.map(&:kind)).to eq([:missing_schema])
    end

    it 'terminates on a self-referencing schema' do
      node_class = Class.new(StructuredParams::Params)
      node_class.attribute :name, :string
      node_class.attribute :children, :array, value_class: node_class
      document = {
        'components' => { 'schemas' => { 'Node' => {
          'type' => 'object',
          'properties' => {
            'name' => { 'type' => 'string' },
            'children' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Node' } }
          }
        } } }
      }

      result = described_class.call(openapi: document, schema: 'Node', parameter_class: node_class)

      expect(result).to be_valid
    end

    it 'reports a dangling nested reference as an error without extra findings' do
      schema['properties']['address'] = { '$ref' => '#/components/schemas/Missing' }
      document = { 'components' => { 'schemas' => { 'Request' => schema } } }

      result = described_class.call(openapi: document, schema: 'Request', parameter_class: parameter_class)

      expect(result.errors).to contain_exactly(
        have_attributes(kind: :unresolved_reference, path: 'address', message: a_string_including('Missing'))
      )
      expect(result.skipped).to be_empty
    end

    it 'reports a circular reference chain instead of recursing forever' do
      schema['properties']['address'] = { '$ref' => '#/components/schemas/Loop' }
      document = { 'components' => { 'schemas' => { 'Request' => schema,
                                                    'Loop' => { '$ref' => '#/components/schemas/Loop' } } } }

      result = described_class.call(openapi: document, schema: 'Request', parameter_class: parameter_class)

      expect(result.errors.map(&:kind)).to eq([:unresolved_reference])
    end

    it 'skips an external reference without extra findings' do
      schema['properties']['address'] = { '$ref' => 'other.yml#/Address' }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped).to contain_exactly(have_attributes(path: 'address',
                                                                message: a_string_including('external')))
    end

    it 'merges sibling keys next to a reference and follows chained references' do
      schema['properties']['address'] = { '$ref' => '#/components/schemas/Alias', 'description' => 'Where to ship' }
      document = {
        'components' => { 'schemas' => {
          'Request' => schema,
          'Alias' => { '$ref' => '#/components/schemas/Address' },
          'Address' => { 'type' => 'object', 'properties' => { 'city' => { 'type' => 'string' } },
                         'required' => ['city'] }
        } }
      }

      result = described_class.call(openapi: document, schema: 'Request', parameter_class: parameter_class)

      expect(result).to be_valid
      expect(result.skipped).to be_empty
    end

    it 'reports a property that has no matching attribute' do
      schema['properties']['nickname'] = { 'type' => 'string' }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result.errors).to contain_exactly(have_attributes(kind: :missing_attribute, path: 'nickname'))
    end

    it 'does not accumulate findings when the same instance is called twice' do
      schema['properties']['nickname'] = { 'type' => 'string' }
      check = described_class.new(schema: schema, parameter_class: parameter_class)

      check.call
      result = check.call

      expect(result.errors.size).to eq(1)
      expect(result.errors).to be_frozen
    end

    it 'skips nullable type arrays, objects without properties and arrays without items' do
      schema['properties']['name'] = { 'type' => %w[string null] }
      schema['properties']['address'] = { 'type' => 'object' }
      schema['properties']['tags'] = { 'type' => 'array' }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result.skipped.map(&:path)).to contain_exactly('name', 'address', 'tags')
    end

    it 'skips a property whose schema is not an object' do
      schema['properties']['name'] = nil

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result.skipped).to contain_exactly(have_attributes(path: 'name'))
    end

    it 'reports a type mismatch for a nested object property and a required nested attribute' do
      schema['properties']['address']['properties']['city'] = { 'type' => 'integer' }

      result = described_class.call(schema: schema, parameter_class: parameter_class)

      expect(result.errors).to contain_exactly(have_attributes(kind: :type_mismatch, path: 'address.city'))
    end

    it 'does not treat a conditional presence validator as unconditional' do
      conditional = Class.new(StructuredParams::Params) do
        attribute :name, :string
        validates :name, presence: true, if: -> { true }
      end
      name_schema = { 'type' => 'object', 'properties' => { 'name' => { 'type' => 'string' } }, 'required' => ['name'] }

      result = described_class.call(schema: name_schema, parameter_class: conditional)

      expect(result.errors.map(&:kind)).to eq([:missing_presence_validation])
    end

    it 'accepts compatible numeric types and rejects an integer attribute for a number schema' do
      numbers = Class.new(StructuredParams::Params) do
        attribute :price, :decimal
        attribute :count, :integer
      end
      number_schema = {
        'type' => 'object',
        'properties' => { 'price' => { 'type' => 'number' }, 'count' => { 'type' => 'number' } }
      }

      result = described_class.call(schema: number_schema, parameter_class: numbers)

      expect(result.errors).to contain_exactly(have_attributes(kind: :type_mismatch, path: 'count'))
    end

    it 'validates constructor arguments' do
      expect { described_class.new(schema: schema, parameter_class: parameter_class, required_validation: :foo) }
        .to raise_error(ArgumentError, /required_validation/)
      expect { described_class.new(parameter_class: parameter_class) }
        .to raise_error(ArgumentError, /configure an OpenAPI document/)
    end

    it 'resolves array indexes in JSON Pointers' do
      document = { 'components' => { 'schemas' => { 'Request' => { 'allOf' => [schema] } } } }

      result = described_class.call(openapi: document, schema: '/components/schemas/Request/allOf/0',
                                    parameter_class: parameter_class)

      expect(result).to be_valid
    end

    it 'accepts string schemas for date and time attributes' do
      date_class = Class.new(StructuredParams::Params) do
        attribute :born_on, :date
        attribute :seen_at, :datetime
      end
      date_schema = {
        'type' => 'object',
        'properties' => {
          'born_on' => { 'type' => 'string', 'format' => 'date' },
          'seen_at' => { 'type' => 'string', 'format' => 'date-time' }
        }
      }

      result = described_class.call(schema: date_schema, parameter_class: date_class)

      expect(result).to be_valid
    end

    it 'loads YAML documents containing unquoted dates' do
      document = { 'components' => { 'schemas' => { 'Request' => schema } } }

      Tempfile.create(['openapi', '.yml']) do |file|
        file.write(document.to_yaml.sub('components:', "info:\n  released: 2024-01-01\ncomponents:"))
        file.flush

        result = described_class.call(openapi: file.path, schema: 'Request', parameter_class: parameter_class)

        expect(result).to be_valid
      end
    end

    it 'prefixes the message with the parameter class name' do
      stub_const('DriftCheckSampleParameter', Class.new(StructuredParams::Params) { attribute :name, :string })
      minimal_schema = { 'type' => 'object', 'properties' => { 'other' => { 'type' => 'string' } } }

      result = described_class.call(schema: minimal_schema, parameter_class: DriftCheckSampleParameter)

      expect(result.to_message).to start_with('DriftCheckSampleParameter')
    end
  end
end
