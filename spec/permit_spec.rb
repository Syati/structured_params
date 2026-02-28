# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'StructuredParams::Params.permit' do
  describe 'Form Object context (with nested params structure)' do
    class UserRegistrationForm < StructuredParams::Params
      attribute :name, :string
      attribute :email, :string
      attribute :age, :integer
    end

    let(:params) do
      ActionController::Parameters.new(
        user_registration: {
          name: 'John Doe',
          email: 'john@example.com',
          age: 30,
          extra_field: 'should be filtered'
        }
      )
    end

    it 'automatically requires and permits parameters from nested structure' do
      permitted = UserRegistrationForm.permit(params)

      expect(permitted).to be_permitted
      expect(permitted[:name]).to eq('John Doe')
      expect(permitted[:email]).to eq('john@example.com')
      expect(permitted[:age]).to eq(30)
      expect(permitted[:extra_field]).to be_nil
    end

    it 'raises ParameterMissing when required key is missing' do
      params = ActionController::Parameters.new(other_key: {})

      expect {
        UserRegistrationForm.permit(params)
      }.to raise_error(ActionController::ParameterMissing)
    end

    context 'with nested objects' do
      class AddressForm < StructuredParams::Params
        attribute :street, :string
        attribute :city, :string
      end

      class UserWithAddressForm < StructuredParams::Params
        attribute :name, :string
        attribute :address, :object, value_class: AddressForm
      end

      let(:params) do
        ActionController::Parameters.new(
          user_with_address: {
            name: 'John',
            address: {
              street: '123 Main St',
              city: 'New York',
              extra: 'filtered'
            }
          }
        )
      end

      it 'permits nested object parameters' do
        permitted = UserWithAddressForm.permit(params)

        expect(permitted).to be_permitted
        expect(permitted[:name]).to eq('John')
        expect(permitted[:address][:street]).to eq('123 Main St')
        expect(permitted[:address][:city]).to eq('New York')
        expect(permitted[:address][:extra]).to be_nil
      end
    end

    context 'with arrays' do
      class ItemForm < StructuredParams::Params
        attribute :title, :string
        attribute :description, :string
      end

      class OrderForm < StructuredParams::Params
        attribute :name, :string
        attribute :items, :array, value_class: ItemForm
        attribute :tags, :array, value_type: :string
      end

      let(:params) do
        ActionController::Parameters.new(
          order: {
            name: 'My Order',
            items: [
              { title: 'Item 1', description: 'Desc 1', extra: 'filtered' },
              { title: 'Item 2', description: 'Desc 2' }
            ],
            tags: ['tag1', 'tag2', 'tag3']
          }
        )
      end

      it 'permits array parameters' do
        permitted = OrderForm.permit(params)

        expect(permitted).to be_permitted
        expect(permitted[:name]).to eq('My Order')
        expect(permitted[:items].length).to eq(2)
        expect(permitted[:items][0][:title]).to eq('Item 1')
        expect(permitted[:items][0][:extra]).to be_nil
        expect(permitted[:tags]).to eq(['tag1', 'tag2', 'tag3'])
      end
    end

    context 'with namespaced form' do
      module Admin
        class UserForm < StructuredParams::Params
          attribute :title, :string
        end
      end

      let(:params) do
        ActionController::Parameters.new(
          admin_user: {
            title: 'Admin Title',
            extra: 'filtered'
          }
        )
      end

      it 'uses correct param_key from model_name' do
        permitted = Admin::UserForm.permit(params)

        expect(permitted).to be_permitted
        expect(permitted[:title]).to eq('Admin Title')
        expect(permitted[:extra]).to be_nil
      end
    end
  end

  describe 'API context (with flat params structure)' do
    class UserParams < StructuredParams::Params
      attribute :name, :string
      attribute :email, :string
      attribute :age, :integer
    end

    let(:params) do
      ActionController::Parameters.new(
        name: 'Jane Doe',
        email: 'jane@example.com',
        age: 25,
        extra_field: 'should be filtered'
      )
    end

    it 'permits parameters without requiring a key' do
      permitted = UserParams.permit(params, require: false)

      expect(permitted).to be_permitted
      expect(permitted[:name]).to eq('Jane Doe')
      expect(permitted[:email]).to eq('jane@example.com')
      expect(permitted[:age]).to eq(25)
      expect(permitted[:extra_field]).to be_nil
    end

    context 'with nested objects' do
      class ApiAddressParams < StructuredParams::Params
        attribute :street, :string
        attribute :city, :string
      end

      class ApiUserParams < StructuredParams::Params
        attribute :name, :string
        attribute :address, :object, value_class: ApiAddressParams
      end

      let(:params) do
        ActionController::Parameters.new(
          name: 'Alice',
          address: {
            street: '456 Oak Ave',
            city: 'Tokyo',
            extra: 'filtered'
          },
          extra_field: 'should be filtered'
        )
      end

      it 'permits nested object parameters without require' do
        permitted = ApiUserParams.permit(params, require: false)

        expect(permitted).to be_permitted
        expect(permitted[:name]).to eq('Alice')
        expect(permitted[:address][:street]).to eq('456 Oak Ave')
        expect(permitted[:address][:city]).to eq('Tokyo')
        expect(permitted[:address][:extra]).to be_nil
        expect(permitted[:extra_field]).to be_nil
      end
    end

    context 'with arrays' do
      class ApiItemParams < StructuredParams::Params
        attribute :title, :string
        attribute :description, :string
      end

      class ApiOrderParams < StructuredParams::Params
        attribute :name, :string
        attribute :items, :array, value_class: ApiItemParams
        attribute :tags, :array, value_type: :string
      end

      let(:params) do
        ActionController::Parameters.new(
          name: 'My Order',
          items: [
            { title: 'Item 1', description: 'Desc 1', extra: 'filtered' },
            { title: 'Item 2', description: 'Desc 2' }
          ],
          tags: ['tag1', 'tag2', 'tag3'],
          extra_field: 'filtered'
        )
      end

      it 'permits array parameters without require' do
        permitted = ApiOrderParams.permit(params, require: false)

        expect(permitted).to be_permitted
        expect(permitted[:name]).to eq('My Order')
        expect(permitted[:items].length).to eq(2)
        expect(permitted[:items][0][:title]).to eq('Item 1')
        expect(permitted[:items][0][:extra]).to be_nil
        expect(permitted[:tags]).to eq(['tag1', 'tag2', 'tag3'])
        expect(permitted[:extra_field]).to be_nil
      end
    end

    context 'when user manually extracts nested params' do
      let(:nested_params) do
        ActionController::Parameters.new(
          user: {
            name: 'Bob',
            email: 'bob@example.com',
            age: 35
          }
        )
      end

      it 'works with manually extracted params' do
        # User manually extracts the nested params
        permitted = UserParams.permit(nested_params[:user], require: false)

        expect(permitted).to be_permitted
        expect(permitted[:name]).to eq('Bob')
        expect(permitted[:email]).to eq('bob@example.com')
        expect(permitted[:age]).to eq(35)
      end
    end
  end
end
