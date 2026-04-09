# frozen_string_literal: true

FactoryBot.define do
  factory :hobby_parameter, class: 'HobbyParameter' do
    name { 'programming' }
    level { 3 }
    years_experience { 10 }

    initialize_with { new(attributes) }
  end
end
