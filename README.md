# StructuredParams

StructuredParams is a Ruby gem that provides type-safe parameter validation and casting for Rails applications. It extends ActiveModel's type system to handle nested objects and arrays with automatic Strong Parameters integration.

English | [日本語](README_ja.md)

## Features

- **Type-safe parameter validation** using ActiveModel::Type
- **Nested object support** with automatic casting
- **Array handling** for both primitive types and nested objects  
- **Strong Parameters integration** with automatic permit lists
- **ActiveModel compatibility** with validations and serialization
- **Enhanced error handling** with flat and structured formats
- **RBS type definitions** for better development experience

## Quick Start

```ruby
# 1. Install the gem
gem 'structured_params'

# 2. Register types in initializer
StructuredParams.register_types

# 3. Define parameter classes
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array, value_class: HobbyParams
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end

# 4. Use in controllers
def create
  user_params = UserParams.new(params[:user])
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors.to_hash(false, structured: true) }
  end
end
```

## Documentation

- **[Installation and Setup](docs/installation.md)** - Getting started with StructuredParams
- **[Basic Usage](docs/basic-usage.md)** - Parameter classes, nested objects, and arrays
- **[Validation](docs/validation.md)** - Using ActiveModel validations with nested structures
- **[Strong Parameters](docs/strong-parameters.md)** - Automatic permit list generation
- **[Error Handling](docs/error-handling.md)** - Flat and structured error formats
- **[Serialization](docs/serialization.md)** - Converting parameters to hashes and JSON
- **[Gem Comparison](docs/comparison.md)** - Comparison with typed_params, dry-validation, and reform

## Example

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string
  
  validates :street, :city, :postal_code, presence: true
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :address, :object, value_class: AddressParams
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# Usage
params = {
  name: "John Doe",
  email: "john@example.com",
  address: { street: "123 Main St", city: "New York", postal_code: "10001" }
}

user_params = UserParams.new(params)
user_params.valid? # => true
user_params.address.city # => "New York"
user_params.attributes # => Hash ready for ActiveRecord
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Syati/structured_params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
