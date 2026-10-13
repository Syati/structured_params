# StructuredParams

English | [日本語](README_ja.md)

**Typed parameter objects and form objects for Rails.**

Supports Ruby `>= 3.2` and Rails / ActiveModel `>= 7.2, < 9.0`.

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
# Gemfile
gem 'structured_params'

# config/initializers/structured_params.rb
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
  attribute :score, :integer
  attribute :tags, :array, value_type: :string           # Primitive array
  attribute :address, :object, value_class: AddressParams # Nested object

  # validate raw string before type casting
  validates_raw :score, format: { with: /\A\d+\z/, message: 'must be numeric string' }
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
  validates :score, numericality: { greater_than_or_equal_to: 0 }
end

# Use in API controller
def create
  user_params = UserParams.new(params)

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
# Passing ActionController::Parameters to a Form class automatically calls
# params.require(:user_registration).permit(...) internally.
# Use a class name ending with `Form` to enable this behavior.
def create
  form = UserRegistrationForm.new(params)

  if form.valid?
    User.create!(form.attributes)
    redirect_to root_path
  else
    render :new
  end
end
```

### 3. OpenAPI Drift Check (optional gem)

Detecting differences between your OpenAPI schemas and Params classes is provided by a
separate gem, [`structured_params-openapi`](structured_params-openapi/README.md):

```ruby
# Gemfile
gem 'structured_params-openapi'
```

```sh
bundle exec rake structured_params:openapi:drift_check
```

## Documentation

- **[Installation and Setup](structured_params/docs/installation.md)** - Getting started with StructuredParams
- **[Basic Usage](structured_params/docs/basic-usage.md)** - Parameter classes, nested objects, and arrays
- **[Validation](structured_params/docs/validation.md)** - Using ActiveModel validations with nested structures
- **[OpenAPI Drift Check](structured_params-openapi/docs/drift-check.md)** - Detect differences between request schemas and Params classes (`structured_params-openapi` gem)
- **[Strong Parameters](structured_params/docs/strong-parameters.md)** - Automatic permit list generation
- **[Error Handling](structured_params/docs/error-handling.md)** - Flat and structured error formats
- **[Serialization](structured_params/docs/serialization.md)** - Converting parameters to hashes and JSON
- **[Form Objects](structured_params/docs/form-objects.md)** - Form object pattern with Rails views

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Syati/structured_params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
