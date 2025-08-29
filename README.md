# StructuredParams

StructuredParams is a Ruby gem that provides type-safe parameter validation and casting for Rails applications. It extends ActiveModel's type system to handle nested objects and arrays with automatic Strong Parameters integration.

English | [日本語](README_ja.md)

## Features

- **Type-safe parameter validation** using ActiveModel::Type
- **Nested object support** with automatic casting
- **Array handling** for both primitive types and nested objects  
- **Strong Parameters integration** with automatic permit lists
- **ActiveModel compatibility** with validations and serialization
- **RBS type definitions** for better development experience

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'structured_params'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install structured_params
```

## Setup

Register the custom types in your Rails application:

```ruby
# config/initializers/structured_params.rb
StructuredParams.register_types
```

This registers `:object` and `:array` types with ActiveModel::Type.

## Usage

### Basic Parameter Class

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :email, :string
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# Usage in controller
def create
  user_params = UserParams.new(params[:user])
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors }
  end
end
```

### Nested Objects

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :address, :object, value_class: AddressParams
end

# Usage
params = {
  name: "John Doe",
  address: {
    street: "123 Main St",
    city: "New York",
    postal_code: "10001"
  }
}

user_params = UserParams.new(params)
user_params.address # => AddressParams instance
user_params.address.city # => "New York"
```

### Arrays

#### Array of Primitive Types

```ruby
class UserParams < StructuredParams::Params
  attribute :tags, :array, value_type: :string
  attribute :scores, :array, value_type: :integer
end

# Usage
params = {
  tags: ["ruby", "rails", "programming"],
  scores: [85, 92, 78]
}

user_params = UserParams.new(params)
user_params.tags # => ["ruby", "rails", "programming"]
user_params.scores # => [85, 92, 78]
```

#### Array of Nested Objects

```ruby
class HobbyParams < StructuredParams::Params
  attribute :name, :string
  attribute :level, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :hobbies, :array, value_class: HobbyParams
end

# Usage
params = {
  name: "Alice",
  hobbies: [
    { name: "Photography", level: "beginner" },
    { name: "Cooking", level: "intermediate" }
  ]
}

user_params = UserParams.new(params)
user_params.hobbies # => [HobbyParams, HobbyParams]
user_params.hobbies.first.name # => "Photography"
```

### Strong Parameters Integration

StructuredParams automatically generates permit lists for Strong Parameters:

```ruby
class UsersController < ApplicationController
  def create
    permitted_params = params.require(:user).permit(*UserParams.permit_attribute_names)
    user_params = UserParams.new(permitted_params)
    
    if user_params.valid?
      User.create!(user_params.attributes)
    else
      render json: { errors: user_params.errors }
    end
  end
end

# UserParams.permit_attribute_names returns:
# [:name, :age, :email, { address: [:street, :city, :postal_code] }, { hobbies: [:name, :level] }]
```

### Validation

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

### Serialization

```ruby
user_params = UserParams.new(params)
user_params.attributes # => Hash with all attributes
user_params.to_json    # => JSON string
```

## Advanced Usage

### Custom Type Registration

If you want to avoid potential naming conflicts, you can register types with custom names:

```ruby
# Register with custom names
StructuredParams.register_types_as(
  object_name: :structured_object,
  array_name: :structured_array
)

# Then use in your parameter classes
class UserParams < StructuredParams::Params
  attribute :address, :structured_object, value_class: AddressParams
  attribute :hobbies, :structured_array, value_class: HobbyParams
end
```

### Type Introspection

```ruby
user_params = UserParams.new(params)

# Check attribute types
UserParams.attribute_types[:name].type        # => :string
UserParams.attribute_types[:address].type     # => :object
UserParams.attribute_types[:hobbies].type     # => :array

# Access nested value classes
UserParams.attribute_types[:address].value_class  # => AddressParams
UserParams.attribute_types[:hobbies].value_class  # => HobbyParams
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Syati/structured_params.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
