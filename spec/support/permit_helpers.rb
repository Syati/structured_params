# frozen_string_literal: true

# rubocop:disable Style/OneClassPerFile
# rbs_inline: enabled

# Test helper classes for permit specs

class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :age, :integer
end

class AddressForm < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
end

class UserWithAddressForm < StructuredParams::Params
  attribute :name, :string
  attribute :address, :object, value_class: AddressForm
end

class ItemForm < StructuredParams::Params
  attribute :title, :string
  attribute :description, :string
end

class OrderForm < StructuredParams::Params
  attribute :name, :string
  attribute :items, :array, value_class: ItemForm
  attribute :tags, :array, value_type: :string
end

module Admin
  class NamespacedForm < StructuredParams::Params
    attribute :title, :string
  end
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :age, :integer
end

class ApiAddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
end

class ApiUserParams < StructuredParams::Params
  attribute :name, :string
  attribute :address, :object, value_class: ApiAddressParams
end

class ApiItemParams < StructuredParams::Params
  attribute :title, :string
  attribute :description, :string
end

class ApiOrderParams < StructuredParams::Params
  attribute :name, :string
  attribute :items, :array, value_class: ApiItemParams
  attribute :tags, :array, value_type: :string
end

# rubocop:enable Style/OneClassPerFile
