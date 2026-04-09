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
    subject(:attributes) do
      build(:user_parameter, **user_param_attributes).attributes(symbolize: symbolize, compact_mode: compact_mode)
    end

    let(:user_param_attributes) { attributes_for(:user_parameter) }
    let(:compact_mode) { :none }

    context 'when symbolize: false' do
      let(:symbolize) { false }

      it { is_expected.to eq user_param_attributes.deep_stringify_keys }
    end

    context 'with symbolize: true' do
      let(:symbolize) { true }

      it { is_expected.to eq user_param_attributes.deep_symbolize_keys }
    end

    context 'with compact_mode: :nil_only' do
      let(:symbolize) { false }
      let(:compact_mode) { :nil_only }

      context 'with nil values' do
        let(:user_param_attributes) do
          {
            name: 'Tanaka Taro',
            email: nil,
            age: 30,
            address: {
              postal_code: '123-4567',
              prefecture: nil,
              city: 'Shibuya-ku',
              street: nil
            },
            hobbies: [
              { name: 'programming', level: 3, years_experience: nil },
              { name: nil, level: 2, years_experience: 5 }
            ],
            tags: %w[Ruby Rails Web]
          }
        end

        let(:expected_result) do
          {
            'name' => 'Tanaka Taro',
            'age' => 30,
            'address' => {
              'postal_code' => '123-4567',
              'city' => 'Shibuya-ku'
            },
            'hobbies' => [
              { 'name' => 'programming', 'level' => 3 },
              { 'level' => 2, 'years_experience' => 5 }
            ],
            'tags' => %w[Ruby Rails Web]
          }
        end

        it 'removes nil values recursively' do
          expect(attributes).to eq(expected_result)
        end
      end

      context 'with symbolize: true and compact_mode: :nil_only' do
        let(:symbolize) { true }
        let(:compact_mode) { :nil_only }

        let(:user_param_attributes) do
          {
            name: 'Tanaka Taro',
            email: nil,
            age: 30,
            address: {
              postal_code: '123-4567',
              prefecture: nil,
              city: 'Shibuya-ku',
              street: nil
            },
            hobbies: nil,
            tags: nil
          }
        end

        let(:expected_result) do
          {
            name: 'Tanaka Taro',
            age: 30,
            address: {
              postal_code: '123-4567',
              city: 'Shibuya-ku'
            }
          }
        end

        it 'symbolizes keys and removes nil values recursively' do
          expect(attributes).to eq(expected_result)
        end
      end
    end

    context 'with compact_mode: :all_blank' do
      let(:symbolize) { false }
      let(:compact_mode) { :all_blank }

      context 'with blank values' do
        let(:user_param_attributes) do
          {
            name: 'Tanaka Taro',
            email: '',
            age: 30,
            address: {
              postal_code: '123-4567',
              prefecture: nil,
              city: 'Shibuya-ku',
              street: ''
            },
            hobbies: [
              { name: 'programming', level: 3, years_experience: nil },
              { name: '', level: 2, years_experience: 5 }
            ],
            tags: %w[Ruby Rails Web]
          }
        end

        let(:expected_result) do
          {
            'name' => 'Tanaka Taro',
            'age' => 30,
            'address' => {
              'postal_code' => '123-4567',
              'city' => 'Shibuya-ku'
            },
            'hobbies' => [
              { 'name' => 'programming', 'level' => 3 },
              { 'level' => 2, 'years_experience' => 5 }
            ],
            'tags' => %w[Ruby Rails Web]
          }
        end

        it 'removes blank values (nil, empty string, etc.) recursively' do
          expect(attributes).to eq(expected_result)
        end
      end
    end
  end

  describe 'raw validations' do
    describe '#valid?' do
      context 'when value matches raw format' do
        subject(:params) { StrictAgeParameter.new(age: '12') }

        it 'is valid' do
          expect(params).to be_valid
        end
      end

      context 'when value fails raw format but would be castable' do
        subject(:params) { StrictAgeParameter.new(age: '12x') }

        it 'adds validation error on raw input' do
          expect(params).not_to be_valid
          expect(params.errors[:age]).to include('must be numeric string')
        end
      end
    end
  end

  describe '.human_attribute_name' do
    context 'with flat attribute (no dot notation)' do
      it 'delegates to default ActiveModel behavior' do
        expect(UserParameter.human_attribute_name(:name)).to eq('Name')
        expect(UserParameter.human_attribute_name(:email)).to eq('Email')
      end
    end

    context 'with nested object attribute (address.postal_code)' do
      it 'delegates leaf attribute to nested class' do
        # AddressParameter.human_attribute_name('postal_code') => "Postal code"
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
      end
    end

    context 'with array attribute (hobbies.0.name)' do
      it 'includes index and delegates leaf to nested class' do
        # default en: "Hobbies 0 Name"
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
      end

      it 'reflects different indices correctly' do
        expect(UserParameter.human_attribute_name(:'hobbies.2.level')).to eq('Hobbies 2 Level')
      end
    end

    context 'with mixed nested path (team.members.1.name)' do
      it 'resolves object and array nesting in one path' do
        expect(OrganizationParameter.human_attribute_name(:'team.members.1.name')).to eq('Team Members 1 Name')
      end
    end

    context 'with deep object nested path (member.organization.name)' do
      it 'resolves multiple object nesting levels' do
        expect(
          OrganizationParameter.human_attribute_name(:'member.organization.name')
        ).to eq('Member Organization Name')
      end
    end

    context 'with i18n overrides' do
      include_context 'with ja locale'

      let(:ja_locale_files) { %w[params_human_attribute_name] }

      it 'formats array nested attribute in Japanese' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
      end

      it 'formats higher index correctly' do
        expect(UserParameter.human_attribute_name(:'hobbies.2.level')).to eq('趣味 2 番目のレベル')
      end

      it 'formats object nested attribute in Japanese' do
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所の郵便番号')
      end

      it 'formats mixed object/array nested attribute in Japanese' do
        expect(OrganizationParameter.human_attribute_name(:'team.members.1.name')).to eq('チームのメンバー 1 番目の名前')
      end

      it 'formats deep object nested attribute in Japanese' do
        expect(OrganizationParameter.human_attribute_name(:'member.organization.name')).to eq('担当者の組織の名称')
      end
    end
  end

  describe 'i18n full_message for array errors' do
    subject(:user_param) do
      build(:user_parameter, hobbies: [{ name: '', level: 5, years_experience: -1 }])
    end

    before { user_param.valid? }

    context 'with default (en) locale' do
      it 'includes index in full_message' do
        full_messages = user_param.errors.map(&:full_message)
        expect(full_messages).to include(match(/Hobbies 0 Name/))
      end
    end

    context 'with i18n overrides (ja)' do
      include_context 'with ja locale'

      let(:ja_locale_files) { %w[params_full_message] }

      it 'uses child model i18n for message body' do
        full_messages = user_param.errors.map(&:full_message)
        expect(full_messages).to include('趣味 0 番目の名前は必須です')
      end

      it 'uses child model i18n for years_experience message' do
        full_messages = user_param.errors.map(&:full_message)
        expect(full_messages).to include('趣味 0 番目の経験年数は0以上にしてください')
      end
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
