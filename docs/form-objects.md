# Using as Form Objects

`StructuredParams::Params` can be used as a Rails form object pattern. Integration with form helpers (`form_with`, `form_for`) makes it easy to use in views.

## Basic Usage

### Defining a Form Object

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

### Using in Controllers

```ruby
class UsersController < ApplicationController
  def new
    @form = UserRegistrationForm.new({})
  end

  def create
    @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
    
    if @form.valid?
      user = User.create!(@form.attributes.except('password_confirmation'))
      redirect_to user, notice: 'User was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
end

# UserRegistrationForm.permit(params) is equivalent to:
# params.require(:user_registration).permit(UserRegistrationForm.permit_attribute_names)
```

### Using in Views

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

### 1. Separation from Models

Using form objects allows you to separate validation logic from models.

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

### 2. Combining Multiple Models

You can easily create forms that handle multiple models together.

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

### 3. Nested Forms

Forms with nested attributes are also easy to handle.

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

`StructuredParams::Params` automatically removes the following suffixes from class names:

- `Parameters` (plural)
- `Parameter` (singular)
- `Form`

```ruby
UserRegistrationForm.model_name.name       # => "UserRegistration"
UserRegistrationForm.model_name.param_key  # => "user_registration"
UserParameters.model_name.name             # => "User"
```

### Nested Modules

When defined within a module, the namespace is preserved:

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

Form objects are integrated with Rails' i18n system.

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

### Using in Views

```erb
<%= form_with model: @form, url: users_path do |f| %>
  <h1><%= @form.model_name.human %></h1>
  
  <%= f.label :name %>
  <%= f.text_field :name %>
  
  <%= f.label :email %>
  <%= f.email_field :email %>
<% end %>
```

## API Integration

Form objects can also be used for API request validation.

```ruby
class Api::V1::UsersController < Api::V1::BaseController
  def create
    @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
    
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

Form objects are automatically integrated with Strong Parameters.

```ruby
class UsersController < ApplicationController
  def create
    # permit method automatically executes require and permit
    @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
    
    if @form.valid?
      # Save to database
      user = User.create!(@form.attributes)
      redirect_to user
    else
      render :new
    end
  end
end

# If you want manual control
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

Form object tests can be easily written with standard RSpec.

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

### 1. Implementing the save Method

Implementing a `save` method in the form object helps keep controllers simple.

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

### 2. Using Transactions

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

### 3. Conditional Validations

You can implement validations based on state.

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
