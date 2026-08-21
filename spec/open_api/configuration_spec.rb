# frozen_string_literal: true

require 'spec_helper'

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
end
