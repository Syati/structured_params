# Strong Parameters Integration

StructuredParams provides three ways to integrate with Strong Parameters depending on your use case.

## Table of Contents

- [API Requests](#api-requests)
- [Form Objects](#form-objects)
- [Manual Control](#manual-control)
- [Automatic Permit List Generation](#automatic-permit-list-generation)
- [Controller Patterns](#controller-patterns)
  - [API Controller](#api-controller)
  - [Form Object Controller](#form-object-controller)
- [How `permit` Determines the Parameter Key](#how-permit-determines-the-parameter-key)
- [Choosing the Right Approach](#choosing-the-right-approach)
  - [`UserParams.new(params)` — Recommended for APIs](#userparamsnewparams--recommended-for-apis)
  - [`permit` method — Required for Form Objects](#permit-method--required-for-form-objects)
  - [`permit_attribute_names` — Manual Control](#permit_attribute_names--manual-control)

## API Requests

For API endpoints, pass `params` directly. Only defined attributes are extracted automatically.

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
end

# Example request body:
# { "name": "John", "email": "john@example.com", "age": 30 }
```

> **Note:** `StructuredParams::Params` automatically extracts only defined attributes from unpermitted `ActionController::Parameters`, providing the same protection as Strong Parameters without explicit `permit` calls.

If you prefer to be explicit, use `permit` with `require: false`:

```ruby
user_params = UserParams.new(UserParams.permit(params, require: false))
```

## Form Objects

For web forms, use `permit` (default `require: true`). It automatically resolves nested parameter keys such as `params[:user_registration]`.

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

# Example form submission:
# params = { user_registration: { name: "John", email: "john@example.com" } }
```

## Manual Control

For fine-grained control, use `permit_attribute_names` directly.

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

> **Note:** Existing code using `permit_attribute_names` continues to work without any changes — full backward compatibility is maintained.

## Automatic Permit List Generation

`permit_attribute_names` automatically generates the correct structure for nested objects and arrays.

```ruby
class UserParams < StructuredParams::Params
  attribute :name,    :string
  attribute :age,     :integer
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array,  value_class: HobbyParams
  attribute :tags,    :array,  value_type: :string
end

UserParams.permit_attribute_names
# => [:name, :age, { address: [:street, :city, :postal_code] }, { hobbies: [:name, :level] }, { tags: [] }]
```

## Controller Patterns

### API Controller

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

### Form Object Controller

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

## How `permit` Determines the Parameter Key

`permit` uses `model_name.param_key` to determine which key to `require`:

```ruby
UserParams.permit(params)
# Internally calls: params.require(:user).permit(...)

UserRegistrationForm.permit(params)
# Internally calls: params.require(:user_registration).permit(...)

Admin::UserForm.permit(params)
# Internally calls: params.require(:admin_user).permit(...)
```

See [Form Objects](form-objects.md) for details on `model_name` customization.

## Choosing the Right Approach

### `UserParams.new(params)` — Recommended for APIs

- ✅ **Simple** — no boilerplate
- ✅ **Automatic filtering** — undefined attributes are excluded
- ✅ **Same protection** — equivalent security to Strong Parameters

```ruby
user_params = UserParams.new(params)
```

### `permit` method — Required for Form Objects

- ✅ **Required for form helpers** — when using `form_with`/`form_for` in views
- ✅ **Nested key resolution** — automatically extracts from `params[:user_registration]` etc.
- ✅ **Explicit intent** — makes Strong Parameters usage clear

```ruby
# Form object - Required
@form = UserRegistrationForm.new(UserRegistrationForm.permit(params))

# API with explicit permit - Optional but acceptable
user_params = UserParams.new(UserParams.permit(params, require: false))
```

### `permit_attribute_names` — Manual Control

- ✅ **Custom permit logic** — add extra fields beyond the defined attributes
- ✅ **Backward compatibility** — drop-in for existing codebases
- ✅ **Fine-grained control** — integrate with complex Strong Parameters code

```ruby
permitted = params.require(:user).permit(*UserParams.permit_attribute_names, :custom_field)
user_params = UserParams.new(permitted)
```
