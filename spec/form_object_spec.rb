# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/DescribeClass
RSpec.describe 'StructuredParams::Params as Form Object' do
  describe '.model_name' do
    it 'removes "Form" suffix from class name' do
      expect(UserRegistrationForm.model_name.name).to eq('UserRegistration')
    end

    it 'provides proper param_key' do
      expect(UserRegistrationForm.model_name.param_key).to eq('user_registration')
    end

    it 'provides proper route_key' do
      expect(UserRegistrationForm.model_name.route_key).to eq('user_registrations')
    end
  end

  describe '#persisted?' do
    it 'returns false' do
      form = UserRegistrationForm.new({})
      expect(form.persisted?).to be(false)
    end
  end

  describe '#to_key' do
    it 'returns nil' do
      form = UserRegistrationForm.new({})
      expect(form.to_key).to be_nil
    end
  end

  describe '#to_model' do
    it 'returns self' do
      form = UserRegistrationForm.new({})
      expect(form.to_model).to eq(form)
    end
  end

  describe 'validation' do
    context 'with valid parameters' do
      let(:params) do
        {
          name: 'John Doe',
          email: 'john@example.com',
          age: 25,
          terms_accepted: true
        }
      end

      it 'is valid' do
        form = UserRegistrationForm.new(params)
        expect(form).to be_valid
      end
    end

    context 'with invalid parameters' do
      let(:params) do
        {
          name: '',
          email: 'invalid-email',
          age: -5,
          terms_accepted: false
        }
      end

      it 'has errors for invalid fields' do
        form = UserRegistrationForm.new(params)
        form.valid?

        expect(form.errors[:name]).to be_present
        expect(form.errors[:email]).to be_present
        expect(form.errors[:age]).to be_present
      end
    end
  end

  describe 'class name with "Parameters" suffix' do
    it 'removes "Parameters" suffix from model_name' do
      expect(OrderParameters.model_name.name).to eq('Order')
      expect(OrderParameters.model_name.param_key).to eq('order')
    end
  end

  describe 'class name with "Parameter" suffix' do
    it 'removes "Parameter" suffix from model_name' do
      expect(PaymentParameter.model_name.name).to eq('Payment')
      expect(PaymentParameter.model_name.param_key).to eq('payment')
    end
  end

  describe 'class name without suffix' do
    it 'keeps the class name as is' do
      expect(Profile.model_name.name).to eq('Profile')
      expect(Profile.model_name.param_key).to eq('profile')
    end
  end

  describe 'nested class within module' do
    it 'keeps namespace and generates model naming keys' do
      expect(Admin::UserForm.model_name.name).to eq('Admin::User')
      expect(Admin::UserForm.model_name.param_key).to eq('admin_user')
      expect(Admin::UserForm.model_name.route_key).to eq('admin_users')
      expect(Admin::UserForm.model_name.i18n_key).to eq(:'admin/user')
    end
  end

  describe 'deeply nested class' do
    it 'keeps deep namespace and generates model naming keys' do
      expect(Api::V1::RegistrationForm.model_name.name).to eq('Api::V1::Registration')
      expect(Api::V1::RegistrationForm.model_name.param_key).to eq('api_v1_registration')
      expect(Api::V1::RegistrationForm.model_name.route_key).to eq('api_v1_registrations')
      expect(Api::V1::RegistrationForm.model_name.i18n_key).to eq(:'api/v1/registration')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
