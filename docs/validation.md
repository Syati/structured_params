# Validation

Since StructuredParams inherits from ActiveModel, you can use all ActiveModel validations:

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :email, :string
  attribute :address, :object, value_class: AddressParams
  
  validates :name, presence: true, length: { minimum: 2 }
  validates :age, presence: true, numericality: { greater_than: 0 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :address, presence: true
  
  validate :custom_validation
  
  private
  
  def custom_validation
    errors.add(:age, "must be adult") if age && age < 18
  end
end
```

## Nested Validation

Validation automatically cascades to nested objects and arrays:

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string
  
  validates :street, presence: true
  validates :city, presence: true
  validates :postal_code, presence: true, format: { with: /\A\d{5}\z/ }
end

class HobbyParams < StructuredParams::Params
  attribute :name, :string
  attribute :level, :string
  
  validates :name, presence: true
  validates :level, inclusion: { in: %w[beginner intermediate advanced] }
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array, value_class: HobbyParams
  
  validates :name, presence: true
  validates :address, presence: true
end
```

When you call `valid?` on the parent object, it automatically validates all nested objects and arrays. Errors from nested objects are aggregated with dot notation (e.g., `address.postal_code`, `hobbies.0.name`).
