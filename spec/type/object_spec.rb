# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Type::Object do
  subject(:type_instance) { described_class.new(value_class: dummy_model_class) }

  let(:dummy_model_class) do
    Class.new(StructuredParams::Params) do
      def self.name
        'DummyModel'
      end

      attribute :name, :string
      attribute :value, :integer

      validates :name, presence: true
    end
  end

  describe '#initialize' do
    context 'with valid value_class' do
      it 'initializes successfully' do
        expect(type_instance.value_class).to eq(dummy_model_class)
      end
    end

    context 'with invalid value_class' do
      it 'raises ArgumentError' do
        expect do
          described_class.new(value_class: String)
        end.to raise_error(ArgumentError, 'value_class must inherit from StructuredParams::Params, got String')
      end
    end
  end

  describe '#type' do
    subject { type_instance.type }

    it { is_expected.to eq(:object) }
  end

  describe '#cast' do
    subject(:cast) { type_instance.cast(value) }

    context 'with nil value' do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context 'with already instantiated model' do
      let(:value) { dummy_model_class.new(name: 'test', value: 42) }

      it { is_expected.to be(value) }
    end

    context 'with hash parameters' do
      let(:value) { { name: 'test', value: 42 } }

      it 'creates new model instance' do
        expect(cast).to be_instance_of(dummy_model_class)
        expect(cast).to have_attributes(name: 'test', value: 42)
      end
    end
  end

  describe '#serialize' do
    subject(:serialize) { type_instance.serialize(value) }

    context 'with nil value' do
      let(:value) { nil }

      it { is_expected.to be_nil }
    end

    context 'with model instance' do
      let(:value) { dummy_model_class.new(name: 'test', value: 42) }

      it 'returns attributes hash' do
        expect(serialize).to be_a(Hash)
        expect(serialize).to match('name' => 'test', 'value' => 42)
      end
    end

    context 'with non-model value' do
      let(:value) { { name: 'test', value: 42 } }

      it 'returns the value as-is' do
        expect(serialize).to be_a(Hash)
        expect(serialize).to match(value)
      end
    end
  end

  describe '#permit_attribute_names' do
    subject { type_instance.permit_attribute_names }

    it { is_expected.to eq(%i[name value]) }
  end
end
