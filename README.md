# StructuredParams

English | [日本語](README_ja.md)

**Type-safe API parameter validation and form objects for Rails**

StructuredParams solves these challenges:

- **API endpoints**: Type checking, validation, and automatic casting of request parameters
- **Form objects**: Validation and conversion of complex form inputs to models

Built on ActiveModel, making nested objects and arrays easy to handle.

## Key Features

- ✅ **API Parameter Validation** - Type-safe request validation
- ✅ **Form Objects** - Encapsulate complex form logic
- ✅ **Nested Structure Support** - Automatic casting for objects and arrays
- ✅ **Strong Parameters Integration** - Auto-generate permit lists
- ✅ **ActiveModel Compatible** - Support for validations, serialization, and other standard features
- ✅ **RBS Type Definitions** - Type-safe development experience

## Quick Start

```ruby
# Installation
gem 'structured_params'

# Initialize
StructuredParams.register_types
```

### 1. API Parameter Validation

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :tags, :array, value_type: :string           # Primitive array
  attribute :address, :object, value_class: AddressParams # Nested object
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end

# Use in API controller
def create
  permitted = UserParams.permit(params, require: false)
  user_params = UserParams.new(permitted)
  
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors }, status: :unprocessable_entity
  end
end
```

#### Primitive arrays

StructuredParams supports primitive arrays via `value_type`. They are permitted using the Strong Parameters array format (`tags: []`).

```ruby
class UserParams < StructuredParams::Params
  attribute :tags, :array, value_type: :string
end

# Equivalent Strong Parameters:
# params.permit(tags: [])
```


### 2. Form Object

```ruby
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :terms_accepted, :boolean
  
  validates :name, :email, presence: true
  validates :terms_accepted, acceptance: true
end

# Use in controller
def create
  form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
  
  if form.valid?
    User.create!(form.attributes)
    redirect_to root_path
  else
    render :new
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


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Syati/structured_params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
