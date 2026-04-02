# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Validations do
  describe '.validates_raw' do
    context 'with single attribute' do
      subject(:params) { StrictAgeParameter.new(age:) }

      context 'when raw value is valid' do
        let(:age) { '12' }

        it { is_expected.to be_valid }
      end

      context 'when raw value is invalid' do
        let(:age) { '12x' }

        it 'adds error to original attribute name' do
          expect(params).not_to be_valid
          expect(params.errors[:age]).to include('must be numeric string')
          expect(params.errors[:age_before_type_cast]).to be_empty
        end
      end
    end

    context 'with multiple attributes' do
      subject(:params) { params_class.new(code:, score:) }

      let(:params_class) do
        stub_const('RawMultiParameter', Class.new(StructuredParams::Params) do
          attribute :code, :string
          attribute :score, :integer

          validates_raw :code, :score, format: { with: /\A\d+\z/, message: 'must be numeric string' }
        end)
      end
      let(:code) { 'A12' }
      let(:score) { '3x' }

      it 'remaps each before_type_cast error to original attribute' do
        expect(params).not_to be_valid
        expect(params.errors[:code]).to include('must be numeric string')
        expect(params.errors[:score]).to include('must be numeric string')
        expect(params.errors[:code_before_type_cast]).to be_empty
        expect(params.errors[:score_before_type_cast]).to be_empty
      end
    end

    context 'when declared multiple times' do
      subject(:params) { params_class.new(code:, score:) }

      let(:params_class) do
        stub_const('RawValidationDeclaredMultipleTimesParameter', Class.new(StructuredParams::Params) do
          attribute :code, :string
          attribute :score, :integer

          validates_raw :code, format: { with: /\A\d+\z/, message: 'code must be numeric string' }
          validates_raw :score, format: { with: /\A\d+\z/, message: 'score must be numeric string' }
        end)
      end
      let(:code) { 'A12' }
      let(:score) { '3x' }

      it 'remaps before_type_cast errors for each declaration' do
        expect(params).not_to be_valid
        expect(params.errors[:code]).to include('code must be numeric string')
        expect(params.errors[:score]).to include('score must be numeric string')
        expect(params.errors[:code_before_type_cast]).to be_empty
        expect(params.errors[:score_before_type_cast]).to be_empty
      end
    end

    context 'when error metadata is preserved via errors.import' do
      subject(:params) { params_class.new(age: 'abc') }

      let(:params_class) do
        stub_const('ErrorMetadataParameter', Class.new(StructuredParams::Params) do
          attribute :age, :integer

          validates_raw :age, format: { with: /\A\d+\z/, message: 'must be numeric string' }
        end)
      end

      before { params.validate }

      it 'preserves structured error type (not a raw message string) in errors.details' do
        # errors.import keeps the original type symbol (e.g. :invalid from format validator)
        # rather than a raw message string like "must be numeric string"
        detail_types = params.errors.details[:age].map { |d| d[:error] }
        expect(detail_types).to all(be_a(Symbol))
      end

      it 'does not leak metadata onto before_type_cast attribute' do
        expect(params.errors.details[:age_before_type_cast]).to be_empty
      end

      it 'keeps the error findable via errors.where with its preserved type' do
        # The format validator internally adds :invalid type
        detail_type = params.errors.details[:age].first[:error]
        error = params.errors.where(:age, detail_type).first
        expect(error).not_to be_nil
        expect(error.type).to eq(detail_type)
      end
    end

    context 'when combined with validates on the same attribute' do
      let(:age) { 'abc' }

      context 'when validates is declared before validates_raw' do
        subject(:params) { params_class.new(age:) }

        let(:params_class) do
          stub_const('CombinedValidationTypedFirstParameter', Class.new(StructuredParams::Params) do
            attribute :age, :integer

            validates :age, numericality: { greater_than: 10, message: 'typed' }
            validates_raw :age, format: { with: /\A\d+\z/, message: 'raw' }
          end)
        end

        it 'collects both errors on the original attribute' do
          expect(params).not_to be_valid
          expect(params.errors[:age]).to contain_exactly('typed', 'raw')
          expect(params.errors[:age_before_type_cast]).to be_empty
        end
      end

      context 'when validates_raw is declared before validates' do
        subject(:params) { params_class.new(age:) }

        let(:params_class) do
          stub_const('CombinedValidationRawFirstParameter', Class.new(StructuredParams::Params) do
            attribute :age, :integer

            validates_raw :age, format: { with: /\A\d+\z/, message: 'raw' }
            validates :age, numericality: { greater_than: 10, message: 'typed' }
          end)
        end

        it 'collects both errors on the original attribute' do
          expect(params).not_to be_valid
          expect(params.errors[:age]).to contain_exactly('typed', 'raw')
          expect(params.errors[:age_before_type_cast]).to be_empty
        end
      end
    end
  end
end
