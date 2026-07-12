# Using as Form Objects

`StructuredParams::Params` can be used as a Rails form object. It integrates with `form_with` / `form_for` and works seamlessly in views.

Classes whose names end with `Form` automatically require and permit the nested root key when initialized with `ActionController::Parameters`.

## Table of Contents

- [Defining a Form Object](#defining-a-form-object)
- [Using in Controllers](#using-in-controllers)
- [Using in Views](#using-in-views)
- [Benefits of Form Objects](#benefits-of-form-objects)
  - [Separation from Models](#separation-from-models)
  - [Combining Multiple Models](#combining-multiple-models)
  - [Nested Forms](#nested-forms)
- [Class Name Conventions](#class-name-conventions)
  - [Nested Modules](#nested-modules)
- [i18n Support](#i18n-support)
  - [Setting Up Translation Files](#setting-up-translation-files)
  - [Customizing Nested Attribute Labels](#customizing-nested-attribute-labels)
- [API Integration](#api-integration)
- [Strong Parameters Integration](#strong-parameters-integration)
- [Testing](#testing)
- [Best Practices](#best-practices)
  - [ActionController::Parameters Support](#actioncontrollerparameters-support)
  - [Implementing a save Method](#implementing-a-save-method)
  - [Using Transactions](#using-transactions)
  - [Conditional Validations](#conditional-validations)
- [Related Documentation](#related-documentation)

## Defining a Form Object

```ruby
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :terms_accepted, :boolean

  validates :name, presence: true, length: { minimum: 2 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 8 }
  validates :password_confirmation, presence: true
  validates :terms_accepted, acceptance: true
  
  validate :passwords_match

  private

  def passwords_match
    return if password == password_confirmation
    
    errors.add(:password_confirmation, "doesn't match password")
  end
end
```

## Using in Controllers

```ruby
class UsersController < ApplicationController
  def new
    @form = UserRegistrationForm.new({})
  end

  def create
    @form = UserRegistrationForm.new(params)
    
    if @form.valid?
      user = User.create!(@form.attributes.except('password_confirmation'))
      redirect_to user, notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end

# UserRegistrationForm.new(params) internally resolves:
# params.require(:user_registration).permit(UserRegistrationForm.permit_attribute_names)
```

## Using in Views

```erb
<%= form_with model: @form, url: users_path do |f| %>
  <% if @form.errors.any? %>
    <div class="error-messages">
      <h2><%= pluralize(@form.errors.count, "error") %> prohibited this registration:</h2>
      <ul>
        <% @form.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="field">
    <%= f.label :name %>
    <%= f.text_field :name %>
  </div>

  <div class="field">
    <%= f.label :email %>
    <%= f.email_field :email %>
  </div>

  <div class="field">
    <%= f.label :password %>
    <%= f.password_field :password %>
  </div>

  <div class="field">
    <%= f.label :password_confirmation %>
    <%= f.password_field :password_confirmation %>
  </div>

  <div class="field">
    <%= f.check_box :terms_accepted %>
    <%= f.label :terms_accepted, "I accept the terms and conditions" %>
  </div>

  <div class="actions">
    <%= f.submit "Sign up" %>
  </div>
<% end %>
```

## Benefits of Form Objects

### Separation from Models

Form objects let you separate validation logic from persistence models.

```ruby
# Model focuses on persistence
class User < ApplicationRecord
  has_secure_password
end

# Form object handles form-specific validations
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  
  validates :password_confirmation, presence: true
  validate :passwords_match
end
```

### Combining Multiple Models

Easily create forms that handle multiple models together.

```ruby
class UserProfileForm < StructuredParams::Params
  attribute :user_name, :string
  attribute :user_email, :string
  attribute :profile, :object, value_class: ProfileAttributes
  
  validates :user_name, presence: true
  validates :user_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  def save
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      user = User.create!(name: user_name, email: user_email)
      Profile.create!(profile.attributes.merge(user: user))
    end
    
    true
  end
end

class ProfileAttributes < StructuredParams::Params
  attribute :bio, :string
  attribute :website, :string
  attribute :location, :string
  
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true
end
```

### Nested Forms

Define forms with nested attributes concisely.

```ruby
class OrderForm < StructuredParams::Params
  attribute :product_name, :string
  attribute :quantity, :integer
  attribute :shipping_address, :object, value_class: AddressForm
  attribute :billing_address, :object, value_class: AddressForm
  
  validates :product_name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end

class AddressForm < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string
  attribute :country, :string
  
  validates :street, :city, :postal_code, :country, presence: true
end
```

## Class Name Conventions

Classes whose names end with `Form` have their `model_name` customized: the `Form` suffix is stripped so form helpers, `param_key`, and i18n keys resolve to the underlying model name.

```ruby
UserRegistrationForm.model_name.name       # => "UserRegistration"
UserRegistrationForm.model_name.param_key  # => "user_registration"
```

Classes without a `Form` suffix — including ones named `...Parameters` or `...Parameter` — use ActiveModel's default `model_name`, based on the class's own name as-is:

```ruby
UserParameters.model_name.name       # => "UserParameters"
UserParameters.model_name.param_key  # => "user_parameters"
```

### Nested Modules

When defined inside a module, the namespace is preserved.

```ruby
module Admin
  class UserForm < StructuredParams::Params
    attribute :name, :string
  end
end

Admin::UserForm.model_name.name       # => "Admin::User"
Admin::UserForm.model_name.param_key  # => "admin_user"
Admin::UserForm.model_name.route_key  # => "admin_users"
```

## i18n Support

Form objects integrate with Rails' i18n system.

### Setting Up Translation Files

```yaml
# config/locales/ja.yml
ja:
  activemodel:
    models:
      user_registration: "ユーザー登録"
    attributes:
      user_registration:
        name: "名前"
        email: "メールアドレス"
        password: "パスワード"
        password_confirmation: "パスワード(確認)"
        terms_accepted: "利用規約への同意"
    errors:
      models:
        user_registration:
          attributes:
            password_confirmation:
              confirmation: "パスワードが一致しません"
```

Use `model_name.human` in views to display the translated model name:

```erb
<%= form_with model: @form, url: users_path do |f| %>
  <h1><%= @form.model_name.human %></h1>
  
  <%= f.label :name %>
  <%= f.text_field :name %>
  
  <%= f.label :email %>
  <%= f.email_field :email %>
<% end %>
```

### Customizing Nested Attribute Labels

Labels for dot-notation nested attributes (e.g. `hobbies.0.name`, `address.postal_code`) can be customized via:

- `activemodel.errors.nested_attribute.array` — label for array elements (uses `%{parent}`, `%{index}`, `%{child}`)
- `activemodel.errors.nested_attribute.object` — label for nested objects (uses `%{parent}`, `%{child}`)

```yaml
# config/locales/ja.yml
ja:
  activemodel:
    attributes:
      user_parameter:
        hobbies: "趣味"
        address: "住所"
      hobby_parameter:
        name: "名前"
      address_parameter:
        postal_code: "郵便番号"
    errors:
      nested_attribute:
        array:  "%{parent} %{index} 番目の%{child}"
        object: "%{parent}の%{child}"
```

Examples (`UserParameter` has no `Form` suffix, so its i18n scope is its own class name):

- `UserParameter.human_attribute_name(:'hobbies.0.name')      # => "趣味 0 番目の名前"`
- `UserParameter.human_attribute_name(:'address.postal_code')  # => "住所の郵便番号"`

## API Integration

Form objects can also be used for API request validation.

```ruby
class Api::V1::UsersController < Api::V1::BaseController
  def create
    @form = UserRegistrationForm.new(params)
    
    if @form.valid?
      user = User.create!(@form.attributes)
      render json: user, status: :created
    else
      render json: { errors: @form.errors }, status: :unprocessable_entity
    end
  end
end
```

## Strong Parameters Integration

Form objects integrate automatically with Strong Parameters.

```ruby
class UsersController < ApplicationController
  def create
    # Form classes automatically call require and permit internally
    @form = UserRegistrationForm.new(params)
    
    if @form.valid?
      user = User.create!(@form.attributes)
      redirect_to user
    else
      render :new
    end
  end
end

# For manual control
class UsersController < ApplicationController
  def create
    permitted_params = params.require(:user_registration).permit(
      UserRegistrationForm.permit_attribute_names
    )
    
    @form = UserRegistrationForm.new(permitted_params)
    
    if @form.valid?
      user = User.create!(@form.attributes)
      redirect_to user
    else
      render :new
    end
  end
end
```

## Testing

Form objects are straightforward to test with standard RSpec.

```ruby
RSpec.describe UserRegistrationForm do
  describe 'validations' do
    it 'is valid with valid attributes' do
      form = UserRegistrationForm.new(
        name: 'John Doe',
        email: 'john@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        terms_accepted: true
      )
      
      expect(form).to be_valid
    end
    
    it 'is invalid without a name' do
      form = UserRegistrationForm.new(name: '')
      expect(form).not_to be_valid
      expect(form.errors[:name]).to be_present
    end
    
    it 'is invalid with a short password' do
      form = UserRegistrationForm.new(password: 'short')
      expect(form).not_to be_valid
      expect(form.errors[:password]).to be_present
    end
  end
  
  describe '#save' do
    it 'creates a user when valid' do
      form = UserRegistrationForm.new(valid_attributes)
      
      expect {
        form.save
      }.to change(User, :count).by(1)
    end
  end
end
```

## Best Practices

### ActionController::Parameters Support

`Form` classes call `require(model_name.param_key).permit(...)` automatically when initialized with `ActionController::Parameters`.

Plain hashes (e.g. in tests or `def new`) are still passed through unchanged:

```ruby
# Works fine in the new action
@form = UserRegistrationForm.new({})

# Works fine in tests
form = UserRegistrationForm.new(name: "Alice", email: "alice@example.com")
```

> **Note:** Automatic nested-key extraction is only enabled for classes whose names end with `Form`. API-oriented parameter classes can continue to use `UserParams.new(params)`.

### Implementing a save Method

Adding a `save` method to the form object keeps controllers simple.

```ruby
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  
  validates :name, :email, :password, presence: true
  
  def save
    return false unless valid?
    
    User.create!(attributes.except('password_confirmation'))
  end
end

# Controller
def create
  @form = UserRegistrationForm.new(user_params)
  
  if @form.save
    redirect_to root_path, notice: 'Successfully registered!'
  else
    render :new
  end
end
```

### Using Transactions

Use transactions when creating multiple models.

```ruby
def save
  return false unless valid?
  
  ActiveRecord::Base.transaction do
    user = User.create!(name: name, email: email)
    Profile.create!(bio: bio, user: user)
  end
  
  true
rescue ActiveRecord::RecordInvalid
  false
end
```

### Conditional Validations

Apply validations conditionally based on state.

```ruby
class UserUpdateForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :current_password, :string
  
  validates :name, :email, presence: true
  validates :current_password, presence: true, if: :password_change?
  validates :password, length: { minimum: 8 }, if: :password_change?
  
  private
  
  def password_change?
    password.present?
  end
end
```

## Related Documentation

- [Basic Usage](basic-usage.md)
- [Validation](validation.md)
- [Error Handling](error-handling.md)
- [Strong Parameters](strong-parameters.md)
