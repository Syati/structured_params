# Strong Parameters Integration

StructuredParams provides flexible ways to handle Strong Parameters for different use cases:

## 1. API Requests (simple)

For API endpoints, simply pass `params` directly:

```ruby
class Api::V1::UsersController < ApplicationController
  def create
    # Simply pass params - unpermitted params are automatically filtered
    user_params = UserParams.new(params)
    
    if user_params.valid?
      user = User.create!(user_params.attributes)
      render json: user, status: :created
    else
      render json: { errors: user_params.errors.to_hash }, status: :unprocessable_entity
    end
  end
end

# Example request body:
# { "name": "John", "email": "john@example.com", "age": 30 }
```

**Note:** `StructuredParams::Params` automatically extracts only defined attributes from unpermitted `ActionController::Parameters`, providing the same protection as Strong Parameters without explicit `permit` calls.

**Alternative (explicit):** If you prefer to be explicit, you can use `permit` with `require: false`:

```ruby
# Explicit permit (optional)
user_params = UserParams.new(UserParams.permit(params, require: false))
```

## 2. Form Objects (with require)

For web forms, use `permit` with default `require: true`:

```ruby
class UsersController < ApplicationController
  def create
    # permit with require - expects params[:user_registration]
    @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
    
    if @form.valid?
      user = User.create!(@form.attributes)
      redirect_to user, notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end

# Example form submission:
# params = { user_registration: { name: "John", email: "john@example.com" } }
```

## 3. Manual Control (Traditional - Backward Compatible)

If you need more control, you can use `permit_attribute_names` directly:

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

**Note:** Both approaches are fully supported and maintain backward compatibility. Existing code using `permit_attribute_names` will continue to work without any changes.

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

### API Controller (Simple)

```ruby
class Api::V1::UsersController < ApplicationController
  def create
    user_params = UserParams.new(params)
    
    if user_params.valid?
      user = User.create!(user_params.attributes)
      render json: user, status: :created
    else
      render json: { errors: user_params.errors.to_hash }, status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])
    user_params = UserParams.new(params)
    
    if user_params.valid? && user.update(user_params.attributes)
      render json: user
    else
      render json: { errors: user_params.errors.to_hash }, status: :unprocessable_entity
    end
  end
end
```

### Form Object Controller (With require)

```ruby
class UsersController < ApplicationController
  def create
    @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
    
    if @form.valid?
      user = User.create!(@form.attributes)
      redirect_to user, notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

## How `permit` determines the parameter key

The `permit` method uses `model_name.param_key` to determine which key to require:

```ruby
UserParams.permit(params)
# Internally calls: params.require(:user).permit(...)

UserRegistrationForm.permit(params)
# Internally calls: params.require(:user_registration).permit(...)

Admin::UserForm.permit(params)
# Internally calls: params.require(:admin_user).permit(...)
```

See [Form Objects](form-objects.md) for more details about `model_name` customization.

## When to use `permit` method?

### Use `UserParams.new(params)` (Recommended for API)
- ✅ **Simple and clean** - No boilerplate code
- ✅ **Automatic filtering** - Unpermitted attributes are automatically filtered
- ✅ **Same protection** - Provides the same security as Strong Parameters

```ruby
# API endpoint - Recommended
user_params = UserParams.new(params)
```

### Use `permit` method (Required for Form Objects)
- ✅ **Required for form helpers** - When using `form_with`/`form_for` in views
- ✅ **Nested param extraction** - Automatically extracts from nested structure like `params[:user_registration]`
- ✅ **Explicit about intent** - Makes it clear you're using Strong Parameters

```ruby
# Form object - Required
@form = UserRegistrationForm.new(UserRegistrationForm.permit(params))

# API with explicit permit - Optional but acceptable
user_params = UserParams.new(UserParams.permit(params, require: false))
```

### Use `permit_attribute_names` (Manual control)
- ✅ **Custom permit logic** - When you need to add extra fields
- ✅ **Backward compatibility** - For existing codebases
- ✅ **Fine-grained control** - When integrating with complex Strong Parameters code

```ruby
# Custom permit logic
permitted = params.require(:user).permit(*UserParams.permit_attribute_names, :custom_field)
user_params = UserParams.new(permitted)
```
