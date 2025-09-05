# Basic Usage

## Basic Parameter Class

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

## Nested Objects

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

## Arrays

### Array of Primitive Types

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

### Array of Nested Objects

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
