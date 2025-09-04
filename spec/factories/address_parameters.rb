# frozen_string_literal: true

class AddressParameter < StructuredParams::Params
  attribute :postal_code, :string
  attribute :prefecture, :string
  attribute :city, :string
  attribute :street, :string

  validates :postal_code, presence: true, format: { with: /\A\d{3}-\d{4}\z/ }
  validates :prefecture, presence: true
  validates :city, presence: true
end

FactoryBot.define do
  factory :address_parameter, class: AddressParameter do
    postal_code { '123-4567' }
    prefecture { 'Tokyo' }
    city { 'Shibuya-ku' }
    street { 'Saka 1-1-1' }

    initialize_with { new(attributes) }
  end
end
