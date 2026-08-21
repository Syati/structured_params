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
  end
end
