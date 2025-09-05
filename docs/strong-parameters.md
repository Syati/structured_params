# Strong Parameters Integration

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

## Automatic Permit List Generation

The `permit_attribute_names` method automatically generates the correct structure for nested objects and arrays:

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array, value_class: HobbyParams
  attribute :tags, :array, value_type: :string
end

UserParams.permit_attribute_names
# => [:name, :age, { address: [:street, :city, :postal_code] }, { hobbies: [:name, :level] }, { tags: [] }]
```

## Controller Pattern

Here's a typical controller pattern using StructuredParams:

```ruby
class UsersController < ApplicationController
  def create
    user_params = build_user_params
    
    if user_params.valid?
      user = User.create!(user_params.attributes)
      render json: UserSerializer.new(user), status: :created
    else
      render json: { 
        errors: user_params.errors.to_hash(false, structured: true) 
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def build_user_params
    permitted_params = params.require(:user).permit(*UserParams.permit_attribute_names)
    UserParams.new(permitted_params)
  end
end
```
