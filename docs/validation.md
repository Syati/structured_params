# Validation

Since StructuredParams inherits from ActiveModel, you can use all standard ActiveModel validations. Validation cascades automatically to nested objects and arrays.

## Table of Contents

- [Basic Validations](#basic-validations)
- [Validate Raw Input (`validates_raw`)](#validate-raw-input-validates_raw)
  - [Combining `validates_raw` and `validates`](#combining-validates_raw-and-validates)
- [Nested Validation](#nested-validation)

## Basic Validations

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

## Validate Raw Input (`validates_raw`)

Use `validates_raw` to validate the original input value before type casting. This is useful for rejecting partially numeric strings like `"12x"` that would otherwise be silently cast.

```ruby
class UserParams < StructuredParams::Params
  attribute :age, :integer

  validates_raw :age, format: { with: /\A\d+\z/, message: 'must be numeric string' }
end

params = UserParams.new(age: '12x')
params.valid? # => false
params.errors.to_hash # => { age: ["must be numeric string"] }
```

`validates_raw` uses `*_before_type_cast` internally, then remaps errors back to the original attribute. As a result, `errors[:age_before_type_cast]` remains empty in normal usage.

### Combining `validates_raw` and `validates`

You can use both on the same attribute. When both fail, each message is added to the same attribute key.

```ruby
class UserParams < StructuredParams::Params
  attribute :score, :integer

  validates_raw :score, format: { with: /\A\d+\z/, message: 'must be numeric string' }
  validates :score, numericality: { greater_than_or_equal_to: 0 }
end

params = UserParams.new(score: 'abc')
params.valid? # => false
params.errors[:score]
# => includes errors from both validates_raw and validates
```

## Nested Validation

Calling `valid?` on a parent object automatically cascades validation to all nested objects and arrays. Errors are aggregated using dot notation (e.g. `address.postal_code`, `hobbies.0.name`).

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

Each element of the `hobbies` array is validated automatically when `valid?` is called — no `validates` declaration is needed on the parent class for array attributes.
