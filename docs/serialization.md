# Serialization

StructuredParams provides multiple ways to serialize your parameter objects:

## Basic Serialization

```ruby
user_params = UserParams.new(params)
user_params.attributes # => Hash with all attributes
user_params.to_json    # => JSON string
```

## Attributes Method

The `attributes` method returns a hash representation of all attributes, with nested objects properly serialized:

```ruby
user_params = UserParams.new({
  name: "John Doe",
  address: { street: "123 Main St", city: "New York" },
  hobbies: [
    { name: "Photography", level: "beginner" },
    { name: "Cooking", level: "intermediate" }
  ]
})

user_params.attributes
# => {
#   "name" => "John Doe",
#   "address" => { "street" => "123 Main St", "city" => "New York" },
#   "hobbies" => [
#     { "name" => "Photography", "level" => "beginner" },
#     { "name" => "Cooking", "level" => "intermediate" }
#   ]
# }
```

## Symbol vs String Keys

By default, `attributes` returns string keys. You can get symbol keys instead:

```ruby
user_params.attributes(symbolize: false)  # Default: string keys
user_params.attributes(symbolize: true)   # Symbol keys
```

## JSON Serialization

StructuredParams integrates with Rails' JSON serialization:

```ruby
user_params.to_json
# => JSON string representation

user_params.as_json
# => Hash ready for JSON serialization
```

## Integration with ActiveRecord

You can easily pass StructuredParams attributes to ActiveRecord models:

```ruby
class UsersController < ApplicationController
  def create
    user_params = UserParams.new(params[:user])
    
    if user_params.valid?
      # Direct attribute passing
      user = User.create!(user_params.attributes)
      
      # Or with specific attributes
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
