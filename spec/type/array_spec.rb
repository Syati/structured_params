# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Type::Array do
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
    subject(:type_instance) { described_class.new(**params) }

    context 'with value_class parameter' do
      let(:params) { { value_class: dummy_model_class } }

      it { expect(type_instance.item_type).to be_instance_of(StructuredParams::Type::Object) }
      it { expect(type_instance.item_type.value_class).to eq(dummy_model_class) }
    end

    context 'with value_type parameter' do
      let(:params) { { value_type: :string } }

      it { expect(type_instance.item_type).to be_instance_of(ActiveModel::Type::String) }
    end

    context 'with both value_class and value_type' do
      let(:params) { { value_class: dummy_model_class, value_type: :string } }

      it 'raises ArgumentError' do
        expect { type_instance }.to raise_error(ArgumentError, 'Specify either value_class or value_type, not both')
      end
    end

    context 'without value_class or value_type' do
      let(:params) { {} }

      it 'raises ArgumentError' do
        expect { type_instance }.to raise_error(ArgumentError, 'Either value_class or value_type must be specified')
      end
    end

    context 'with invalid value_class' do
      let(:params) { { value_class: String } }

      it 'raises ArgumentError' do
        expect { type_instance }.to(
          raise_error(ArgumentError, 'value_class must inherit from StructuredParams::Params, got String')
        )
      end
    end
  end

  describe '#type' do
    subject { described_class.new(value_type: :string).type }

    it { is_expected.to eq(:array) }
  end

  describe '#cast' do
    context 'with object type' do
      subject(:cast) { described_class.new(value_class: dummy_model_class).cast(value) }

      context 'with array of hashes' do
        let(:value) { [{ name: 'item1', value: 1 }, { name: 'item2', value: 2 }] }

        it { is_expected.to be_an(Array) }
        it { expect(cast).to contain_exactly(dummy_model_class, dummy_model_class) }
        it { expect(cast.first).to have_attributes(name: 'item1', value: 1) }
        it { expect(cast.last).to have_attributes(name: 'item2', value: 2) }
      end

      context 'with single hash (not array)' do
        let(:value) { { name: 'single', value: 42 } }

        it { is_expected.to be_an(Array) }
        it { expect(cast).to contain_exactly(dummy_model_class) }
        it { expect(cast.first).to have_attributes(name: 'single', value: 42) }
      end

      context 'with others' do
        where(:value, :expected) do
          [
            [nil, nil],
            [[], []]
          ]
        end
        with_them do
          it { is_expected.to eq(expected) }
        end
      end
    end

    context 'with primitive type' do
      subject(:cast) { described_class.new(value_type: :string).cast(value) }

      where(:value, :expected) do
        [
          [%w[item1 item2 item3], %w[item1 item2 item3]],
          [[1, 'two', 3.0], ['1', 'two', '3.0']]
        ]
      end
      with_them do
        it { is_expected.to eq(expected) }
      end
    end
  end

  describe '#serialize' do
    context 'with object type' do
      subject(:serialize) { described_class.new(value_class: dummy_model_class).serialize(value) }

      context 'with array of model instances' do
        let(:value) do
          [
            dummy_model_class.new(name: 'item1', value: 1),
            dummy_model_class.new(name: 'item2', value: 2)
          ]
        end

        it { is_expected.to be_an(Array) }

        it {
          expect(serialize).to(contain_exactly(
                                 { 'name' => 'item1', 'value' => 1 },
                                 { 'name' => 'item2', 'value' => 2 }
                               ))
        }
      end

      context 'with others' do
        where(:case_name, :value, :expected) do
          [
            ['nil', nil, nil],
            ['empty array', [], []],
            ['non-array value', 'm', []]
          ]
        end
        with_them do
          it { is_expected.to eq(expected) }
        end
      end
    end

    context 'with primitive type' do
      subject(:serialize) { described_class.new(value_type: :string).serialize(value) }

      context 'with array of strings' do
        let(:value) { %w[item1 item2 item3] }

        it { is_expected.to eq(value) }
      end
    end
  end

  describe '#permit_attribute_names' do
    subject(:permit_attribute_names) do
      described_class.new(**params).permit_attribute_names
    end

    where(:params, :expected) do
      [
        [{ value_class: dummy_model_class }, %i[name value]],
        [{ value_type: :string }, []]
      ]
    end

    with_them do
      it { is_expected.to eq(expected) }
    end
  end

  describe '#item_type_is_structured_params_object?' do
    subject(:item_type_is_structured_params_object?) do
      described_class.new(**params).item_type_is_structured_params_object?
    end

    context 'with object type' do
      let(:params) { { value_class: dummy_model_class } }

      it { is_expected.to be true }
    end

    context 'with primitive type' do
      let(:params) { { value_type: :string } }

      it { is_expected.to be false }
    end
  end
end
