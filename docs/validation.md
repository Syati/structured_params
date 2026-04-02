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

## Validate Raw Input (`validates_raw`)

Use `validates_raw` to validate the original input value before type casting.

```ruby
class UserParams < StructuredParams::Params
  attribute :age, :integer

  # Validate raw input before type casting to avoid accepting partially numeric strings (e.g. "12x").
  validates_raw :age, format: { with: /\A\d+\z/, message: 'must be numeric string' }
end

params = UserParams.new(age: '12x')
params.valid? # => false
params.errors.to_hash # => { age: ["must be numeric string"] }
```

`validates_raw` uses `*_before_type_cast` internally, then remaps errors back to the original attribute.
So `errors[:age_before_type_cast]` remains empty in normal usage.

### Combining `validates_raw` and `validates` on the same attribute

You can use both on the same attribute.

```ruby
class UserParams < StructuredParams::Params
  attribute :score, :integer

  validates_raw :score, format: { with: /\A\d+\z/, message: 'must be numeric string' }
  validates :score, numericality: { greater_than_or_equal_to: 0 }
end

params = UserParams.new(score: 'abc')
params.valid? # => false
params.errors[:score]
# => includes both "must be numeric string" and "is not a number"
```

When both validations fail, both messages are added to the same attribute (`:score`).

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
