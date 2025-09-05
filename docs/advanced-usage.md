# Advanced Usage

## Type Introspection

You can inspect the types and structure of your parameter classes:

```ruby
user_params = UserParams.new(params)

# Check attribute types
UserParams.attribute_types[:name].type        # => :string
UserParams.attribute_types[:address].type     # => :object
UserParams.attribute_types[:hobbies].type     # => :array

# Access nested value classes
UserParams.attribute_types[:address].value_class  # => AddressParams
UserParams.attribute_types[:hobbies].value_class  # => HobbyParams
```

## Custom Type Registration

For advanced scenarios, you can register custom types:

```ruby
class CustomParams < StructuredParams::Params
  # Register with custom names to avoid conflicts
  attribute :config, :structured_object, value_class: ConfigParams
  attribute :items, :structured_array, value_class: ItemParams
end
```

## Conditional Validation

You can implement complex validation logic:

```ruby
class UserParams < StructuredParams::Params
  attribute :user_type, :string
  attribute :company_name, :string
  attribute :personal_info, :object, value_class: PersonalInfoParams
  
  validates :user_type, inclusion: { in: %w[individual business] }
  validates :company_name, presence: true, if: :business_user?
  validates :personal_info, presence: true, if: :individual_user?
  
  private
  
  def business_user?
    user_type == 'business'
  end
  
  def individual_user?
    user_type == 'individual'
  end
end
```

## Dynamic Attribute Definition

For cases where you need dynamic attributes:

```ruby
class ConfigParams < StructuredParams::Params
  # Define attributes dynamically based on configuration
  def self.define_config_attributes(config_schema)
    config_schema.each do |field_name, field_type|
      attribute field_name.to_sym, field_type
    end
  end
end

# Usage
ConfigParams.define_config_attributes({
  'api_key' => :string,
  'timeout' => :integer,
  'enabled' => :boolean
})
```

## Performance Considerations

### Permit List Caching

For better performance, cache permit lists:

```ruby
class UserParams < StructuredParams::Params
  # ... attribute definitions
  
  def self.cached_permit_names
    @cached_permit_names ||= permit_attribute_names.freeze
  end
end

# In controller
def user_params
  @user_params ||= begin
    permitted = params.require(:user).permit(*UserParams.cached_permit_names)
    UserParams.new(permitted)
  end
end
```

### Memory Optimization

For large nested structures, consider lazy loading:

```ruby
class LargeDataParams < StructuredParams::Params
  attribute :metadata, :object, value_class: MetadataParams
  attribute :large_dataset, :array, value_class: DataPointParams
  
  # Only validate what's necessary
  validates :metadata, presence: true
  
  private
  
  def validate_large_dataset
    return unless large_dataset&.any?
    
    # Validate only first few items for performance
    large_dataset.first(10).each_with_index do |item, index|
      next if item.valid?
      
      item.errors.each do |error|
        errors.add("large_dataset.#{index}.#{error.attribute}", error.message)
      end
    end
  end
end
```
