# frozen_string_literal: true

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
