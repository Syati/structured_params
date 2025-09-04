# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Params do
  describe '.permit_attribute_names' do
    subject(:permit_attribute_names) do
      UserParameter.permit_attribute_names
    end

    it {
      expect(permit_attribute_names).to eq([:name, :email, :age,
                                            { address: %i[postal_code prefecture city street] },
                                            { hobbies: %i[name level years_experience] },
                                            { tags: [] }])
    }
  end

  describe '.new' do
    let(:valid_params) do
      {
        name: 'Tanaka Taro',
        email: 'tanaka@example.com',
        age: 30,
        address: {
          postal_code: '123-4567',
          prefecture: 'Tokyo',
          city: 'Shibuya-ku',
          street: 'Saka 1-2-3'
        },
        hobbies: [
          { name: 'programming', level: 3, years_experience: 10 },
          { name: 'Web', level: 2, years_experience: 5 }
        ],
        tags: %w[Ruby Rails Web]
      }
    end

    context 'with valid parameters' do
      subject(:user_param) { build(:user_parameter, **valid_params) }

      it {
        expect(user_param).to have_attributes(
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30
        )
      }

      context 'with object parameters' do
        subject(:address) { user_param.address }

        it { is_expected.to be_instance_of(AddressParameter) }

        it {
          expect(address).to have_attributes(
            postal_code: '123-4567',
            prefecture: 'Tokyo',
            city: 'Shibuya-ku',
            street: 'Saka 1-2-3'
          )
        }
      end

      context 'with object array parameters' do
        subject(:hobbies) { user_param.hobbies }

        it { is_expected.to be_an(Array) }
        it { is_expected.to contain_exactly(HobbyParameter, HobbyParameter) }
        it { expect(hobbies[0]).to have_attributes(name: 'programming', level: 3, years_experience: 10) }
        it { expect(hobbies[1]).to have_attributes(name: 'Web', level: 2, years_experience: 5) }
      end

      context 'with array of strings' do
        subject { user_param.tags }

        it { is_expected.to eq(%w[Ruby Rails Web]) }
      end
    end

    context 'with ActionController::Parameters' do
      subject(:user_param) { UserParameter.new(action_controller_params) }

      let(:action_controller_params) do
        ActionController::Parameters.new(valid_params.merge(unpermitted: 'value'))
      end

      it 'filters unpermitted parameters' do
        expect(user_param.name).to eq('Tanaka Taro')
        expect { user_param.unpermitted }.to raise_error(NoMethodError)
      end
    end

    context 'with invalid parameter type' do
      it 'raises ArgumentError' do
        expect { UserParameter.new('invalid') }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#valid?' do
    context 'with valid object parameters' do
      subject(:user_param) { build(:user_parameter) }

      it { is_expected.to be_valid }
    end

    context 'with invalid parent parameters' do
      subject(:user_param) do
        build(:user_parameter,
              name: '',
              email: 'invalid-email',
              age: -1)
      end

      it 'returns false and includes parent validation errors' do
        expect(user_param).not_to be_valid
        expect(user_param.errors[:name]).to include("can't be blank")
        expect(user_param.errors[:email]).to include('is invalid')
        expect(user_param.errors[:age]).to include('must be greater than 0')
      end
    end

    context 'with invalid object single object' do
      subject(:user_param) do
        build(:user_parameter,
              name: '', # blank
              address: {
                postal_code: 'invalid', # invalid format
                prefecture: '', # blank
                city: 'Shibuya-ku',
                street: 'Saka 1-2-3'
              })
      end

      it 'returns false and includes object validation errors' do
        expect(user_param).not_to be_valid
        expect(user_param.errors[:name]).to include("can't be blank")
        expect(user_param.errors[:'address.postal_code']).to include('is invalid')
        expect(user_param.errors[:'address.prefecture']).to include("can't be blank")
      end
    end

    context 'with invalid object array objects' do
      subject(:user_param) do
        build(:user_parameter,
              hobbies: [
                { name: '', level: 5, years_experience: -1 }, # all invalid
                { name: 'valid hobby', level: 2, years_experience: 3 } # valid
              ])
      end

      it 'returns false and includes array validation errors with index' do
        expect(user_param).not_to be_valid
        expect(user_param.errors[:'hobbies.0.name']).to include("can't be blank")
        expect(user_param.errors[:'hobbies.0.level']).to include('is not included in the list')
        expect(user_param.errors[:'hobbies.0.years_experience']).to include('must be greater than or equal to 0')
      end
    end
  end

  describe '#attributes' do
    subject(:attributes) { build(:user_parameter, **user_param_attributes).attributes(symbolize: symbolize) }

    let(:user_param_attributes) { attributes_for(:user_parameter) }

    context 'when symbolize: false' do
      let(:symbolize) { false }

      it { is_expected.to eq user_param_attributes.deep_stringify_keys }
    end

    context 'with symbolize: true' do
      let(:symbolize) { true }

      it { is_expected.to eq user_param_attributes.deep_symbolize_keys }
    end
  end

  describe 'edge cases' do
    subject(:user_param) { build(:user_parameter, **params) }

    context 'with nil object values' do
      let(:params) do
        {
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30,
          address: nil,
          hobbies: nil,
          tags: nil
        }
      end

      it { is_expected.to be_valid }

      it 'handles nil values gracefully' do
        expect(user_param.address).to be_nil
        expect(user_param.hobbies).to be_nil
        expect(user_param.tags).to be_nil
      end
    end

    context 'with empty arrays' do
      let(:params) do
        {
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30,
          hobbies: [],
          tags: []
        }
      end

      it { is_expected.to be_valid }

      it 'handles empty arrays gracefully' do
        expect(user_param.hobbies).to eq([])
        expect(user_param.tags).to eq([])
      end
    end
  end
end
