# Serialization

StructuredParams provides multiple ways to serialize parameter objects to Hash or JSON. Nested objects are serialized recursively.

## Table of Contents

- [attributes Method](#attributes-method)
- [Symbol vs String Keys](#symbol-vs-string-keys)
- [JSON Serialization](#json-serialization)
- [Integration with ActiveRecord](#integration-with-activerecord)

## attributes Method

`attributes` returns all attributes as a nested Hash.

```ruby
user_params = UserParams.new({
  name: "John Doe",
  address: { street: "123 Main St", city: "New York" },
  hobbies: [
    { name: "Photography", level: "beginner" },
    { name: "Cooking",     level: "intermediate" }
  ]
})

user_params.attributes
# => {
#   "name"    => "John Doe",
#   "address" => { "street" => "123 Main St", "city" => "New York" },
#   "hobbies" => [
#     { "name" => "Photography", "level" => "beginner" },
#     { "name" => "Cooking",     "level" => "intermediate" }
#   ]
# }
```

## Symbol vs String Keys

`attributes` returns string keys by default. Pass `symbolize: true` to get symbol keys instead.

```ruby
user_params.attributes                    # => string keys (default)
user_params.attributes(symbolize: true)   # => symbol keys
```

## JSON Serialization

StructuredParams integrates with Rails' JSON serialization:

```ruby
user_params.to_json   # => JSON string
user_params.as_json   # => Hash ready for JSON serialization
```

## Integration with ActiveRecord

Pass `attributes` directly to ActiveRecord models:

```ruby
class UsersController < ApplicationController
  def create
    user_params = UserParams.new(params[:user])
    
    if user_params.valid?
      # Pass all attributes at once
      user = User.create!(user_params.attributes)
      
      # Or exclude specific attributes
      user = User.new
      user.assign_attributes(user_params.attributes.except('internal_field'))
      user.save!
      
      render json: user
    else
      render json: { errors: user_params.errors }, status: :unprocessable_entity
    end
  end
end
```
