# Comparison with Similar Gems

This document compares StructuredParams with other parameter handling gems in the Ruby/Rails ecosystem.

## Overview Comparison

| Feature | StructuredParams | typed_params | dry-validation | reform |
|---------|------------------|--------------|----------------|---------|
| Type Safety | ✅ ActiveModel::Type | ✅ Built-in types | ✅ Schema validation | ✅ Form objects |
| Nested Objects | ✅ Native support | ❌ Limited | ✅ Schema nesting | ✅ Composition |
| Array Handling | ✅ Typed arrays | ❌ Basic arrays | ✅ Array validation | ✅ Collection forms |
| Strong Parameters | ✅ Auto-generation | ❌ Manual | ❌ Manual | ❌ Manual |
| ActiveModel Integration | ✅ Full compatibility | ❌ Limited | ❌ None | ✅ Full compatibility |
| Error Handling | ✅ Flat & structured | ✅ Basic | ✅ Detailed | ✅ ActiveModel errors |
| RBS Support | ✅ Built-in | ❌ None | ❌ None | ❌ None |

## Detailed Comparison

### vs. typed_params

**typed_params** provides basic type casting but lacks advanced features:

```ruby
# typed_params - Basic usage
class UserController < ApplicationController
  typed_params do
    param :name, type: String, required: true
    param :age, type: Integer
  end
end

# StructuredParams - Advanced features
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array, value_class: HobbyParams
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end
```

**Advantages of StructuredParams:**
- Native nested object support
- Typed array handling
- Automatic Strong Parameters integration
- Full ActiveModel validation support
- Enhanced error handling with structured formats

### vs. dry-validation

**dry-validation** is a powerful validation library but requires more setup:

```ruby
# dry-validation - Schema definition
UserContract = Dry::Validation.Contract do
  params do
    required(:name).filled(:string)
    required(:age).filled(:integer)
    optional(:address).hash do
      required(:street).filled(:string)
      required(:city).filled(:string)
    end
  end
  
  rule(:age) { failure('must be positive') if value <= 0 }
end

# StructuredParams - Simpler approach
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParams
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end
```

**Advantages of StructuredParams:**
- More Rails-friendly syntax
- Built-in Strong Parameters support
- ActiveModel compatibility for serialization
- Less boilerplate code
- Native object composition

### vs. reform

**reform** provides form objects but with different focus:

```ruby
# reform - Form object approach
class UserForm < Reform::Form
  property :name
  property :age
  
  collection :addresses do
    property :street
    property :city
  end
  
  validates :name, presence: true
end

# StructuredParams - Parameter object approach
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :addresses, :array, value_class: AddressParams
  
  validates :name, presence: true
end
```

**Advantages of StructuredParams:**
- Focus on parameter handling rather than form rendering
- Automatic type casting with ActiveModel::Type
- Built-in Strong Parameters integration
- Cleaner syntax for API-first applications
- Better TypeScript/RBS integration

## When to Choose StructuredParams

Choose **StructuredParams** when you need:

1. **Type-safe parameter handling** in Rails APIs
2. **Complex nested structures** with automatic casting
3. **Strong Parameters integration** without manual permit lists
4. **ActiveModel compatibility** for validations and serialization
5. **Enhanced error handling** with structured formats
6. **RBS type definitions** for better development experience

## Migration Examples

### From typed_params

```ruby
# Before: typed_params
class UsersController < ApplicationController
  typed_params do
    param :user, type: Hash do
      param :name, type: String, required: true
      param :age, type: Integer
    end
  end
  
  def create
    # Manual parameter extraction and validation
  end
end

# After: StructuredParams  
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  
  validates :name, presence: true
end

class UsersController < ApplicationController
  def create
    user_params = UserParams.new(params[:user])
    if user_params.valid?
      User.create!(user_params.attributes)
    else
      render json: { errors: user_params.errors.to_hash }
    end
  end
end
```

### From dry-validation

```ruby
# Before: dry-validation
UserContract = Dry::Validation.Contract do
  params do
    required(:name).filled(:string)
    required(:age).filled(:integer)
  end
end

def create
  result = UserContract.call(params[:user])
  if result.success?
    User.create!(result.to_h)
  else
    render json: { errors: result.errors.to_h }
  end
end

# After: StructuredParams
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  
  validates :name, presence: true
end

def create
  user_params = UserParams.new(params[:user])
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors.to_hash }
  end
end
```

## Performance Considerations

StructuredParams leverages ActiveModel::Type system, which provides:

- **Efficient type casting** with built-in Rails optimizations
- **Memory-efficient validation** using ActiveModel's proven patterns  
- **Lazy loading** of nested objects only when accessed
- **Cached permit lists** for Strong Parameters integration

For high-throughput APIs, StructuredParams typically performs comparably to or better than manual parameter handling while providing significantly more features and type safety.
