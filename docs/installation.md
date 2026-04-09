# Installation and Setup

Steps to add StructuredParams to a Rails application.

## Table of Contents

- [Installation](#installation)
- [Setup](#setup)
- [Custom Type Registration](#custom-type-registration)

## Installation

Add the gem to your Gemfile:

```ruby
gem 'structured_params'
```

```bash
bundle install
```

Or install it directly:

```bash
gem install structured_params
```

## Setup

Register the custom types in a Rails initializer:

```ruby
# config/initializers/structured_params.rb
StructuredParams.register_types
```

This registers the `:object` and `:array` types with ActiveModel::Type.

## Custom Type Registration

To avoid naming conflicts with existing code, register the types under custom names:

```ruby
StructuredParams.register_types_as(
  object_name: :structured_object,
  array_name:  :structured_array
)

# Then use in your parameter classes
class UserParams < StructuredParams::Params
  attribute :address, :structured_object, value_class: AddressParams
  attribute :hobbies, :structured_array,  value_class: HobbyParams
end
```
