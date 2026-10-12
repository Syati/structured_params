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
# Run the specs of every gem (from the repository root)
bundle exec rake spec

# The repository holds two gems, each in its own folder:
#   structured_params/          the core gem
#   structured_params-openapi/  the OpenAPI drift check gem
cd structured_params

# Run all tests of the gem
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

This command uses `fswatch` to monitor the `lib/` directory of each gem and automatically runs `rbs-inline` when files change.

### Manual Generation

Generate all signatures manually:

```bash
# Generate for all lib files (run inside each gem folder, e.g. structured_params/)
cd structured_params && bundle exec rbs-inline --output=sig lib/**/*.rb
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
      run: (cd structured_params && bundle exec rbs-inline --output=sig lib/**/*.rb) && ...
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
# Instance variable
class Example
  # @rbs @name: String?
  
  #: (String) -> void
  def initialize(name)
    @name = name
  end
end

# Class instance variable (use self.@)
class Example
  class << self
    # @rbs self.@cache: Hash[Symbol, String]?
    
    def cache
      @cache ||= {}
    end
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
.                                     # repository root: README, Gemfile, Rakefile, Steepfile, lefthook.yml, RuboCop config
├── structured_params/                # core gem
│   ├── structured_params.gemspec
│   ├── Rakefile                      # build/release tasks for this gem
│   ├── CHANGELOG.md
│   ├── lib/
│   │   ├── structured_params.rb      # Main entry point
│   │   └── structured_params/
│   │       ├── params.rb             # Core Params class
│   │       ├── errors.rb             # Enhanced error handling
│   │       ├── version.rb            # Version constant
│   │       └── type/
│   │           ├── array.rb          # Array type handler
│   │           └── object.rb         # Object type handler
│   ├── sig/                          # Auto-generated RBS files (DO NOT EDIT)
│   ├── spec/                         # RSpec tests
│   │   ├── factories/                # Test parameter classes
│   │   ├── support/                  # Test helpers
│   │   └── *_spec.rb                 # Test files
│   └── docs/                         # Documentation
└── structured_params-openapi/        # OpenAPI drift check gem (same layout: gemspec, Rakefile, CHANGELOG.md, lib/, sig/, spec/, docs/)
```

## Releasing

The repository holds two gems, each released from a GitHub Release with its own tag. The core gem is released first when a change needs both (the openapi gem depends on `structured_params >= 0.9.5`; raise that bound if it needs newer core behaviour).

| Gem | Release tag | Workflow | Version file |
|-----|-------------|----------|--------------|
| `structured_params` | `vX.Y.Z` | `release.yml` | `structured_params/lib/structured_params/version.rb` |
| `structured_params-openapi` | `openapi-vX.Y.Z` | `release-openapi.yml` | `structured_params-openapi/lib/structured_params/openapi/version.rb` |

To release a gem:

1. Make sure `main` contains the changes to ship and CI is green. **Do not edit `version.rb` or `CHANGELOG.md` yourself**; the workflow writes both.
2. Create a GitHub Release (published, not a draft or pre-release) with a new tag from the table, targeting `main`, and write the release notes. Pushing a tag alone does nothing.
3. Publishing the Release runs the workflow, which:
   - checks that the tag looks like `vX.Y.Z` / `openapi-vX.Y.Z`, that its commit is on `main`, and that the version does not go backwards;
   - sets `VERSION`, prepends the release notes to the gem's `CHANGELOG.md` and commits both;
   - builds the gem, pushes that commit to `main`, moves the Release's tag onto it, then publishes the gem to RubyGems through Trusted Publishing.

Things to know:

- The Release creates its tag first, then the workflow commits the version and CHANGELOG and **force-moves the tag onto that commit**, so the tag contains exactly what is published. This needs permission to update tags (tag protection rules that forbid it would fail the job before anything is published).
- If a run fails, re-run it: the steps are idempotent (the CHANGELOG entry is not added twice and an already pushed commit is a no-op). A gem that was already published to RubyGems cannot be published again, so a failure after publishing needs a new version.
- Pre-releases are ignored by the workflows, and a tag that matches neither `v*` nor `openapi-v*` releases nothing. If `main` has branch protection, the `github-actions` bot must be allowed to push to it.
- The two workflows share a `concurrency` group because both push to `main`; keep the tag prefixes consistent in three places: the workflow `if:` and tag parsing, and `tag_prefix` in the gem's `Rakefile`.

One-time setup for a new gem: on rubygems.org, register a (pending) Trusted Publisher for `structured_params-openapi` with owner `Syati`, repository `structured_params`, workflow filename `release-openapi.yml` and no environment. The publisher is bound to the workflow's file name, so do not rename `release.yml` or `release-openapi.yml` without updating it. The first publish of a new gem name consumes the pending publisher.

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
