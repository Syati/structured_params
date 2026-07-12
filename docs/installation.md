# Installation and Setup

Steps to add StructuredParams to a Rails application.

## Table of Contents

- [Installation](#installation)
- [Setup](#setup)
- [Configuration](#configuration)
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

This registers the `:object` and `:array` types with `ActiveModel::Type`.

The registration is explicit on purpose:

- `:object` and `:array` are convenient names in application code
- They are also generic names, so auto-registering them at gem load time could silently collide with other code
- Keeping registration in an initializer makes the opt-in explicit and keeps custom aliases available when needed

If you skip this step, `attribute :name, :object` and `attribute :name, :array` will not resolve to
StructuredParams' types in ActiveModel type lookup.

## Configuration

You can configure StructuredParams in the same initializer:

```ruby
# config/initializers/structured_params.rb
StructuredParams.register_types

StructuredParams.configure do |config|
  # Controls how array indices appear in human attribute names and full_messages.
  #   0 (default) — 0-based: "Hobbies 0 Name can't be blank"
  #   1           — 1-based: "Hobbies 1 Name can't be blank"
  config.array_index_base = 1
end
```

If you only need configuration and want to avoid the default names, use `register_types_as(...)` first and then configure in the same initializer.

| Option | Default | Description |
|--------|---------|-------------|
| `array_index_base` | `0` | Index base for array elements in error messages (`0` or `1`) |

> **Note:** `array_index_base` affects `human_attribute_name` and therefore `full_messages`.
> For APIs returning raw error keys (the typical pattern), this setting has no visible effect.

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

Prefer custom names if your app or another gem already uses `:object` or `:array` in `ActiveModel::Type`.
