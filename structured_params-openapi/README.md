# structured_params-openapi

English | [日本語](README_ja.md)

OpenAPI drift check for [StructuredParams](https://github.com/Syati/structured_params).
It detects differences between OpenAPI request schemas and `StructuredParams::Params`
classes, so a change on one side cannot silently diverge from the other.

## Installation

```ruby
# Gemfile
gem 'structured_params-openapi'
```

Bundler requires it automatically (`structured_params/openapi`). In a Rails application
the Rake task `structured_params:openapi:drift_check` is registered for you.

## Usage

```ruby
# config/initializers/structured_params_openapi.rb
StructuredParams::OpenAPI.configure do |config|
  config.document = Rails.root.join('docs/api/openapi.yaml').to_s
  config.parameter_class_filter = ->(klass) { klass.name&.start_with?('Api::') }
end
```

```sh
bundle exec rake structured_params:openapi:drift_check
```

See the [guide](docs/drift-check.md) for naming conventions, multiple OpenAPI files,
ignoring findings, and the supported schema features.
