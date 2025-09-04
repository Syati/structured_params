# frozen_string_literal: true

class HobbyParameter < StructuredParams::Params
  attribute :name, :string
  attribute :level, :integer
  attribute :years_experience, :integer

  validates :name, presence: true
  validates :level, inclusion: { in: 1..3 }
  validates :years_experience, numericality: { greater_than_or_equal_to: 0 }
end

FactoryBot.define do
  factory :hobby_parameter, class: HobbyParameter do
    name { 'programming' }
    level { 3 }
    years_experience { 10 }

    initialize_with { new(attributes) }
  end
end
