# Installation and Setup

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
