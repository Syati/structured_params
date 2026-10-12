# frozen_string_literal: true

FactoryBot.define do
  factory :address_parameter, class: 'AddressParameter' do
    postal_code { '123-4567' }
    prefecture { 'Tokyo' }
    city { 'Shibuya-ku' }
    street { 'Saka 1-1-1' }

    initialize_with { new(attributes) }
  end
end
