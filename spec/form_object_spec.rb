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

    it 'provides proper singular form' do
      expect(UserRegistrationForm.model_name.singular).to eq('user_registration')
    end

    it 'provides proper plural form' do
      expect(UserRegistrationForm.model_name.plural).to eq('user_registrations')
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

      it 'is invalid' do
        form = UserRegistrationForm.new(params)
        expect(form).not_to be_valid
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

  describe 'integration with Rails form helpers' do
    it 'provides all necessary methods for form_with' do
      form = UserRegistrationForm.new({})

      # form_with requires these methods
      expect(form).to respond_to(:model_name)
      expect(form).to respond_to(:persisted?)
      expect(form).to respond_to(:to_key)
      expect(form).to respond_to(:to_model)
      expect(form).to respond_to(:errors)
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
    it 'handles namespace correctly in name' do
      expect(Admin::UserForm.model_name.name).to eq('Admin::User')
    end

    it 'provides correct param_key with namespace' do
      # Rails includes namespace in param_key when full name is provided
      expect(Admin::UserForm.model_name.param_key).to eq('admin_user')
    end

    it 'provides correct route_key with namespace' do
      expect(Admin::UserForm.model_name.route_key).to eq('admin_users')
    end

    it 'provides correct i18n_key with namespace' do
      expect(Admin::UserForm.model_name.i18n_key).to eq(:'admin/user')
    end
  end

  describe 'deeply nested class' do
    it 'handles multiple namespaces correctly in name' do
      expect(Api::V1::RegistrationForm.model_name.name).to eq('Api::V1::Registration')
    end

    it 'provides correct param_key for deeply nested class' do
      expect(Api::V1::RegistrationForm.model_name.param_key).to eq('api_v1_registration')
    end

    it 'provides correct route_key for deeply nested class' do
      expect(Api::V1::RegistrationForm.model_name.route_key).to eq('api_v1_registrations')
    end

    it 'provides correct i18n_key for deeply nested class' do
      expect(Api::V1::RegistrationForm.model_name.i18n_key).to eq(:'api/v1/registration')
    end
  end

  describe 'nested class with Parameters suffix' do
    it 'removes suffix and keeps namespace' do
      expect(Internal::OrderParameters.model_name.name).to eq('Internal::Order')
    end

    it 'provides correct param_key' do
      expect(Internal::OrderParameters.model_name.param_key).to eq('internal_order')
    end

    it 'provides correct i18n_key' do
      expect(Internal::OrderParameters.model_name.i18n_key).to eq(:'internal/order')
    end
  end
end
# rubocop:enable RSpec/DescribeClass
