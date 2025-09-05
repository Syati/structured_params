# Error Handling

StructuredParams provides enhanced error handling for nested structures with a custom `Errors` class that supports both flat and structured error formats:

## Basic Error Access

```ruby
user_params = UserParams.new(invalid_params)
user_params.valid? # => false

# Standard error access (flat structure with dot notation)
user_params.errors.to_hash
# => { :name => ["can't be blank"], :'address.postal_code' => ["can't be blank"] }

# Full error messages
user_params.errors.full_messages
# => ["Name can't be blank", "Address postal code can't be blank"]
```

## Structured Error Format

For better integration with frontend applications, you can get errors in a nested structure:

```ruby
# Get errors in structured format (symbol keys)
user_params.errors.to_hash(false, structured: true)
# => {
#      :name => ["can't be blank"],
#      :address => { :postal_code => ["can't be blank"] },
#      :hobbies => { :'0' => { :name => ["can't be blank"] } }
#    }

# With full error messages
user_params.errors.to_hash(true, structured: true)
# => {
#      :name => ["Name can't be blank"],
#      :address => { :postal_code => ["Address postal code can't be blank"] }
#    }
```

## Custom Error Key Formatting

You can transform error keys using standard Ruby methods for different output formats:

```ruby
# JSON Pointer format
user_params.errors.to_hash.transform_keys { |key| "/#{key.to_s.gsub('.', '/')}" }
# => { "/name" => ["can't be blank"], "/address/postal_code" => ["can't be blank"] }

# Uppercase format
user_params.errors.to_hash.transform_keys(&:upcase)
# => { "NAME" => ["can't be blank"], "ADDRESS.POSTAL_CODE" => ["can't be blank"] }

# Custom prefix
user_params.errors.to_hash.transform_keys { |key| "field_#{key}" }
# => { "field_name" => ["can't be blank"], "field_address.postal_code" => ["can't be blank"] }
```

## API Response Examples

### JSON API Format

```ruby
class UsersController < ApplicationController
  def create
    user_params = UserParams.new(params[:user])
    
    if user_params.valid?
      User.create!(user_params.attributes)
      render json: { success: true }
    else
      # Choose the error format that best fits your frontend needs
      render json: { 
        errors: user_params.errors.to_hash(false, structured: true),
        success: false 
      }, status: :unprocessable_entity
    end
  end
end
```

### JSON:API Compliant Format

```ruby
def create
  user_params = UserParams.new(params[:user])
  
  if user_params.valid?
    # ... success handling
  else
    # Transform to JSON:API errors format
    json_api_errors = user_params.errors.to_hash.map do |field, messages|
      messages.map do |message|
        {
          source: { pointer: "/data/attributes/#{field.to_s.gsub('.', '/')}" },
          detail: message
        }
      end
    end.flatten
    
    render json: { errors: json_api_errors }, status: :unprocessable_entity
  end
end
```
