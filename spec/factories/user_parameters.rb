# frozen_string_literal: true

class UserParameter < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParameter
  attribute :hobbies, :array, value_class: HobbyParameter
  attribute :tags, :array, value_type: :string

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { greater_than: 0 }
end

FactoryBot.define do
  factory :user_parameter, class: 'UserParameter' do
    name { 'Tanaka Taro' }
    email { 'tanaka@example.com' }
    age { 30 }
    address { attributes_for(:address_parameter) }
    hobbies { attributes_for_list(:hobby_parameter, 2) }
    tags { %w[Ruby Rails Web] }

    initialize_with { new(attributes) }
  end
end
