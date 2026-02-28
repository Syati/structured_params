# frozen_string_literal: true

# rubocop:disable Style/OneClassPerFile
# rbs_inline: enabled

# Test helper classes for form object specs
# These classes are used to test StructuredParams::Params as form objects

class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :age, :integer
  attribute :terms_accepted, :boolean

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { greater_than: 0 }
end

class OrderParameters < StructuredParams::Params
  attribute :product_name, :string
end

class PaymentParameter < StructuredParams::Params
  attribute :amount, :decimal
end

class Profile < StructuredParams::Params
  attribute :bio, :string
end

module Admin
  class UserForm < StructuredParams::Params
    attribute :name, :string
  end
end

module Api
  module V1
    class RegistrationForm < StructuredParams::Params
      attribute :email, :string
    end
  end
end

module Internal
  class OrderParameters < StructuredParams::Params
    attribute :item_name, :string
  end
end

# rubocop:enable Style/OneClassPerFile
