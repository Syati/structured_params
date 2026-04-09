# frozen_string_literal: true

require 'uri'

# Classes primarily used by:
# - spec/form_object_spec.rb
# - spec/permit_spec.rb (UserRegistrationForm, Admin::NamespacedForm)

# Form object with validations
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :age, :integer
  attribute :terms_accepted, :boolean

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { greater_than: 0 }
end

# Classes for testing suffix removal
class OrderParameters < StructuredParams::Params
  attribute :product_name, :string
end

class PaymentParameter < StructuredParams::Params
  attribute :amount, :decimal
end

class Profile < StructuredParams::Params
  attribute :bio, :string
end

# Namespaced classes for testing model_name / permit
module Admin
  class UserForm < StructuredParams::Params
    attribute :name, :string
  end

  class NamespacedForm < StructuredParams::Params
    attribute :title, :string
  end
end

module Api
  module V1
    class RegistrationForm < StructuredParams::Params
      attribute :email, :string
    end
  end
end
