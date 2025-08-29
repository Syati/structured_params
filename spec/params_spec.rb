# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Params do
  # Test parameter class definitions
  let(:address_parameter_class) do
    Class.new(described_class) do
      def self.name
        'AddressParameter'
      end

      attribute :postal_code, :string
      attribute :prefecture, :string
      attribute :city, :string
      attribute :street, :string

      validates :postal_code, presence: true, format: { with: /\A\d{3}-\d{4}\z/ }
      validates :prefecture, presence: true
      validates :city, presence: true
    end
  end

  let(:hobby_parameter_class) do
    Class.new(described_class) do
      def self.name
        'HobbyParameter'
      end

      attribute :name, :string
      attribute :level, :integer
      attribute :years_experience, :integer

      validates :name, presence: true
      validates :level, inclusion: { in: 1..3 }
      validates :years_experience, numericality: { greater_than_or_equal_to: 0 }
    end
  end

  let(:user_parameter_class) do
    address_class = address_parameter_class
    hobby_class = hobby_parameter_class

    Class.new(described_class) do
      def self.name
        'UserParameter'
      end

      attribute :name, :string
      attribute :email, :string
      attribute :age, :integer
      attribute :address, :object, value_class: address_class
      attribute :hobbies, :array, value_class: hobby_class
      attribute :tags, :array, value_type: :string

      validates :name, presence: true, length: { maximum: 50 }
      validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
      validates :age, numericality: { greater_than: 0 }
    end
  end

  describe '.permit_attribute_names' do
    subject(:permit_attribute_names) { user_parameter_class.permit_attribute_names }

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
          { name: '読書', level: 2, years_experience: 5 }
        ],
        tags: %w[Ruby Rails 技術書]
      }
    end

    context 'with valid parameters' do
      subject(:user_param) { user_parameter_class.new(valid_params) }

      it {
        expect(user_param).to have_attributes(
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30
        )
      }

      context 'with object parameters' do
        subject(:address) { user_param.address }

        it { is_expected.to be_instance_of(address_parameter_class) }

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
        it { is_expected.to contain_exactly(hobby_parameter_class, hobby_parameter_class) }
        it { expect(hobbies[0]).to have_attributes(name: 'programming', level: 3, years_experience: 10) }
        it { expect(hobbies[1]).to have_attributes(name: '読書', level: 2, years_experience: 5) }
      end

      context 'with array of strings' do
        subject { user_param.tags }

        it { is_expected.to eq(%w[Ruby Rails 技術書]) }
      end
    end

    context 'with ActionController::Parameters' do
      subject(:user_param) { user_parameter_class.new(action_controller_params) }

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
        expect { user_parameter_class.new('invalid') }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#valid?' do
    context 'with valid object parameters' do
      subject(:user_param) { user_parameter_class.new(valid_params) }

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
            { name: 'programming', level: 3, years_experience: 10 }
          ]
        }
      end

      it { is_expected.to be_valid }
    end

    context 'with invalid parent parameters' do
      subject(:user_param) { user_parameter_class.new(invalid_parent_params) }

      let(:invalid_parent_params) do
        {
          name: '', # invalid
          email: 'invalid-email', # invalid
          age: -1, # invalid
          address: {
            postal_code: '123-4567',
            prefecture: 'Tokyo',
            city: 'Shibuya-ku',
            street: 'Saka 1-2-3'
          }
        }
      end

      it 'returns false and includes parent validation errors' do
        expect(user_param).not_to be_valid
        expect(user_param.errors[:name]).to include("can't be blank")
        expect(user_param.errors[:email]).to include('is invalid')
        expect(user_param.errors[:age]).to include('must be greater than 0')
      end
    end

    context 'with invalid object single object' do
      subject(:user_param) { user_parameter_class.new(invalid_address_params) }

      let(:invalid_address_params) do
        {
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30,
          address: {
            postal_code: 'invalid', # invalid format
            prefecture: '', # blank
            city: 'Shibuya-ku',
            street: 'Saka 1-2-3'
          }
        }
      end

      it 'returns false and includes object validation errors' do
        expect(user_param).not_to be_valid
        expect(user_param.errors['address.postal_code']).to include('is invalid')
        expect(user_param.errors['address.prefecture']).to include("can't be blank")
      end
    end

    context 'with invalid object array objects' do
      subject(:user_param) { user_parameter_class.new(invalid_hobbies_params) }

      let(:invalid_hobbies_params) do
        {
          name: 'Tanaka Taro',
          email: 'tanaka@example.com',
          age: 30,
          hobbies: [
            { name: '', level: 5, years_experience: -1 }, # all invalid
            { name: 'valid hobby', level: 2, years_experience: 3 } # valid
          ]
        }
      end

      it 'returns false and includes array validation errors with index' do
        expect(user_param).not_to be_valid
        expect(user_param.errors['hobbies.0.name']).to include("can't be blank")
        expect(user_param.errors['hobbies.0.level']).to include('is not included in the list')
        expect(user_param.errors['hobbies.0.years_experience']).to include('must be greater than or equal to 0')
      end
    end
  end

  describe '#attributes' do
    subject(:attributes) { user_parameter_class.new(params).attributes(symbolize: symbolize) }

    let(:symbolize) { false }

    let(:params) do
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
          { name: 'programming', level: 3, years_experience: 10 }
        ],
        tags: %w[Ruby Rails]
      }
    end

    it 'returns attributes with objects converted to hashes' do
      expect(attributes).to include(
        'name' => 'Tanaka Taro',
        'address' => hash_including(
          'postal_code' => '123-4567',
          'prefecture' => 'Tokyo',
          'city' => 'Shibuya-ku',
          'street' => 'Saka 1-2-3'
        ),
        'hobbies' => array_including(
          hash_including('name' => 'programming', 'level' => 3, 'years_experience' => 10)
        ),
        'tags' => %w[Ruby Rails]
      )
    end

    context 'with symbolize: true' do
      let(:symbolize) { true }

      it 'returns symbolized attributes' do
        expect(attributes).to include(
          name: 'Tanaka Taro',
          address: hash_including(
            postal_code: '123-4567',
            prefecture: 'Tokyo',
            city: 'Shibuya-ku',
            street: 'Saka 1-2-3'
          ),
          hobbies: array_including(
            hash_including(name: 'programming', level: 3, years_experience: 10)
          ),
          tags: %w[Ruby Rails]
        )
      end
    end
  end

  describe 'edge cases' do
    context 'with nil object values' do
      subject(:user_param) { user_parameter_class.new(params_with_nil) }

      let(:params_with_nil) do
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
      subject(:user_param) { user_parameter_class.new(params_with_empty_arrays) }

      let(:params_with_empty_arrays) do
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
