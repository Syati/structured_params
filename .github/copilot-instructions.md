# Copilot Instructions for structured_params

## Coding Style

### RBS Inline

This project uses `rbs-inline` for type annotations. Use the **method_type_signature** style:

```ruby
# Good: method_type_signature style
class Example
  #: () -> String
  def method_name
    "result"
  end
  
  #: (String) -> Integer
  def method_with_param(value)
    value.length
  end
  
  #: (String value, ?Integer default) -> String
  def method_with_optional(value, default: 0)
    "#{value}: #{default}"
  end
end
```

**Exception: Instance variables** must use doc style (`# @rbs`):

```ruby
# Good: instance variable type definition
class Example
  # @rbs @name: String?
  
  class << self
    # @rbs self.@cache: Hash[Symbol, String]?
  end
  
  #: (String) -> void
  def initialize(name)
    @name = name
  end
end
```

**DO NOT** use the doc style for method signatures:

```ruby
# Bad: doc style for methods (do not use)
# @rbs return: String
def method_name
  "result"
end

# @rbs param: String
# @rbs return: Integer
def method_with_param(value)
  value.length
end
```

### Configuration

The RuboCop configuration enforces this style:

```yaml
Style/RbsInline/MissingTypeAnnotation:
  EnforcedStyle: method_type_signature
```

### RBS Signature Generation

**DO NOT** manually edit files in `sig/` directory. These files are auto-generated from inline annotations.

To generate RBS signature files:

```bash
# Run this command to generate sig files from inline annotations
lefthook run prepare-commit-msg
```

This command will:
1. Extract type annotations from Ruby files using `rbs-inline`
2. Generate corresponding `.rbs` files in `sig/` directory
3. Ensure type signatures are in sync with the code

**Note:** The `sig/` directory is automatically updated by the git hook, but you can manually run it when needed.

## Project-Specific Guidelines

### Strong Parameters

- For API usage: Use simple `UserParams.new(params)` 
- For Form Objects: Use `UserForm.new(UserForm.permit(params))`
- `permit` method is available but not required for API usage

### Form Objects

This gem supports both Strong Parameters validation and Form Object pattern:

- Form Objects should use `permit(params)` to handle `require` + `permit`
- `model_name` automatically removes "Parameters", "Parameter", or "Form" suffix
- Provides `persisted?`, `to_key`, `to_model` for Rails form helpers integration

### Testing

- Use RSpec for testing
- Group tests by context (e.g., "API context", "Form Object context")
- Test files are in `spec/` directory
- Support files (test helper classes) are in `spec/support/`
