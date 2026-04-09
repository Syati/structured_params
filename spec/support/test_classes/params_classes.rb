# frozen_string_literal: true

require 'uri'

# rubocop:disable Style/OneClassPerFile

# Classes primarily used by:
# - spec/params_spec.rb
# - spec/i18n_spec.rb
# - spec/attribute_methods_spec.rb
# - spec/validations_spec.rb
# - spec/permit_spec.rb (UserParameter)

class StrictAgeParameter < StructuredParams::Params
  attribute :age, :integer

  validates_raw :age, format: { with: /\A\d+\z/, message: 'must be numeric string' }
end

class AddressParameter < StructuredParams::Params
  attribute :postal_code, :string
  attribute :prefecture, :string
  attribute :city, :string
  attribute :street, :string

  validates :postal_code, presence: true, format: { with: /\A\d{3}-\d{4}\z/ }
  validates :prefecture, presence: true
  validates :city, presence: true
end

class HobbyParameter < StructuredParams::Params
  attribute :name, :string
  attribute :level, :integer
  attribute :years_experience, :integer

  validates :name, presence: true
  validates :level, inclusion: { in: 1..3 }
  validates :years_experience, numericality: { greater_than_or_equal_to: 0 }
end

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

class MemberOrganizationParameter < StructuredParams::Params
  attribute :name, :string
end

class TeamMemberParameter < StructuredParams::Params
  attribute :name, :string
  attribute :organization, :object, value_class: MemberOrganizationParameter
end

class OrganizationParameter < StructuredParams::Params
  attribute :team, :array, value_class: TeamMemberParameter
end

# rubocop:enable Style/OneClassPerFile
