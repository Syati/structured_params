# Contributing to StructuredParams

Thank you for your interest in contributing to StructuredParams! This document provides guidelines and information for developers.

## Development Setup

### Prerequisites

- Ruby 3.2 or higher (Ruby 3.3+ required for RBS inline features)
- Bundler

### Installation

```bash
# Clone the repository
git clone https://github.com/Syati/structured_params.git
cd structured_params

# Setup everything (installs dependencies, RBS collection, and git hooks)
bin/setup
```

## Development Workflow

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/params_spec.rb

# Run with coverage
bundle exec rspec --format documentation
```

### Code Quality Checks

```bash
# Run RuboCop
bundle exec rubocop

# Auto-correct RuboCop offenses
bundle exec rubocop -a

# Run Steep type checker (Ruby 3.3+ only)
bundle exec steep check
```

## RBS Type Signature Generation

This project uses `rbs-inline` for type annotations. RBS signature files in the `sig/` directory are **auto-generated** from inline type annotations in Ruby files.

**DO NOT manually edit files in the `sig/` directory.**

### During Development (Watch Mode)

Automatically regenerate signatures on file changes:

```bash
./bin/dev
```

This command uses `fswatch` to monitor the `lib/` directory and automatically runs `rbs-inline` when files change.

### Manual Generation

Generate all signatures manually:

```bash
# Generate for all lib files
bundle exec rbs-inline --output=sig lib/**/*.rb
```

### Automatic Generation (Git Hooks)

RBS signatures are automatically generated before each commit via Lefthook:

```bash
# Manually trigger the pre-commit hook
lefthook run prepare-commit-msg
```

The git hook configuration is in `lefthook.yml`:

```yaml
prepare-commit-msg:
  commands:
    rbs-inline:
      run: bundle exec rbs-inline --output=sig lib/**/*.rb
```

## Coding Style

### RBS Inline Annotations

This project uses `rbs-inline` with the **method_type_signature** style:

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
class Example
  # @rbs @name: String?
  
  class << self
    # @rbs @cache: Hash[Symbol, String]?
  end
  
  #: (String) -> void
  def initialize(name)
    @name = name
  end
end
```

**DO NOT use doc style for method signatures:**

```ruby
# Bad: doc style for methods (do not use)
# @rbs return: String
def method_name
  "result"
end
```

### RuboCop Configuration

The project enforces this style via RuboCop:

```yaml
Style/RbsInline/MissingTypeAnnotation:
  EnforcedStyle: method_type_signature
```

## Testing Different Rails Versions

You can test against different Rails versions using the `RAILS_VERSION` environment variable:

```bash
# Test with Rails 7.2
RAILS_VERSION="~> 7.2.0" bundle update && bundle exec rspec

# Test with Rails 8.0
RAILS_VERSION="~> 8.0.0" bundle update && bundle exec rspec
```

## Project Structure

```
structured_params/
├── lib/
│   ├── structured_params.rb          # Main entry point
│   ├── structured_params/
│   │   ├── params.rb                 # Core Params class
│   │   ├── errors.rb                 # Enhanced error handling
│   │   ├── version.rb                # Version constant
│   │   └── type/
│   │       ├── array.rb              # Array type handler
│   │       └── object.rb             # Object type handler
├── sig/                              # Auto-generated RBS files
│   └── generated/                    # DO NOT EDIT
├── spec/                             # RSpec tests
│   ├── factories/                    # Test parameter classes
│   ├── support/                      # Test helpers
│   └── *_spec.rb                     # Test files
└── docs/                             # Documentation
```

## Submitting Changes

### Pull Request Process

1. **Fork the repository** and create your branch from `main`
2. **Write tests** for your changes
3. **Update documentation** if needed (README, docs/, inline comments)
4. **Ensure all tests pass**: `bundle exec rspec`
5. **Ensure code quality**: `bundle exec rubocop`
6. **Ensure type safety** (Ruby 3.3+): `bundle exec steep check`
7. **RBS signatures will be auto-generated** by git hooks
8. **Write a clear commit message** describing your changes
9. **Submit a pull request** with a description of your changes

## Reporting Issues

When reporting issues, please include:

- Ruby version (`ruby -v`)
- Rails version (if applicable)
- Gem version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Code samples or error messages

## Questions?

If you have questions about contributing, feel free to:

- Open an issue with the `question` label
- Start a discussion in GitHub Discussions
- Contact the maintainers

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you are expected to uphold this code.

## License

By contributing to StructuredParams, you agree that your contributions will be licensed under the [MIT License](LICENSE.txt).
