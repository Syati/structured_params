# StructuredParams

StructuredParams is a Ruby gem that provides type-safe parameter validation and casting for Rails applications. It extends ActiveModel's type system to handle nested objects and arrays with automatic Strong Parameters integration.

English | [日本語](README_ja.md)

## Features

- **Type-safe parameter validation** using ActiveModel::Type
- **Nested object support** with automatic casting
- **Array handling** for both primitive types and nested objects  
- **Strong Parameters integration** with automatic permit lists
- **ActiveModel compatibility** with validations and serialization
- **Form object pattern support** with Rails form helpers integration
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

# 4. Use in controllers (API)
def create
  user_params = UserParams.new(params)
  
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors.to_hash(false, structured: true) }
  end
end

# 5. Use as Form Objects (View Integration)

# Define a Form Object class
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# Use in controllers
def create
  @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
  
  if @form.valid?
    User.create!(@form.attributes)
    redirect_to user_path
  else
    render :new
  end
end

# Use in views
<%= form_with model: @form, url: users_path do |f| %>
  <%= f.text_field :name %>
  <%= f.email_field :email %>
  <%= f.password_field :password %>
<% end %>
```

## Documentation

- **[Installation and Setup](docs/installation.md)** - Getting started with StructuredParams
- **[Basic Usage](docs/basic-usage.md)** - Parameter classes, nested objects, and arrays
- **[Validation](docs/validation.md)** - Using ActiveModel validations with nested structures
- **[Strong Parameters](docs/strong-parameters.md)** - Automatic permit list generation
- **[Form Objects](docs/form-objects.md)** - Using as form objects with Rails form helpers
- **[Error Handling](docs/error-handling.md)** - Flat and structured error formats
- **[Serialization](docs/serialization.md)** - Converting parameters to hashes and JSON
- **[Gem Comparison](docs/comparison.md)** - Comparison with typed_params, dry-validation, and reform
- **[Contributing Guide](CONTRIBUTING.md)** - Developer setup and guidelines

## For Developers

If you're interested in contributing to this project, please see [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, RBS generation, testing guidelines, and more.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Syati/structured_params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
