# OpenAPI Drift Check

Configure the application-wide OpenAPI document once and select the namespace of
request parameter classes to check. The Rake task discovers these classes after
Rails eager loads the application.

```ruby
StructuredParams::OpenApi.configure do |config|
  config.document = Rails.root.join('openapi.yml').to_s
  config.parameter_class_filter = ->(parameter_class) do
    parameter_class.name&.start_with?('Api::')
  end
end
```

```sh
bundle exec rake structured_params:openapi:drift_check
```

By default, `CreateUserParams` is matched with
`#/components/schemas/CreateUser`: the class's namespace and a trailing
`Params`, `Parameter`, `Parameters`, or `Form` are removed. Override the
convention globally when necessary.

```ruby
StructuredParams::OpenApi.configure do |config|
  config.schema_name_resolver = ->(parameter_class) do
    "#{parameter_class.name.demodulize.delete_suffix('Params')}Request"
  end
end
```

For an exceptional class, pass only its component name rather than another
file path.

```ruby
StructuredParams::OpenApi::DriftCheck.call(
  parameter_class: CreateUserParams,
  schema: 'CreateUserRequest'
)
```

The checker compares schema properties with `attribute` declarations, scalar and
nested object/array types, and schema `required` properties with unconditional
`validates ..., presence: true` declarations. Use `property_names` when the JSON
property name differs from the Ruby attribute name.

```ruby
StructuredParams::OpenApi::DriftCheck.call(
  parameter_class: CreateUserParams,
  property_names: { user_id: 'userId' }
)
```

In RSpec, use the result as the failure message so a CI failure lists every
detected difference.

```ruby
it 'matches the request schema' do
  result = StructuredParams::OpenApi::DriftCheck.call(
    parameter_class: CreateUserParams
  )

  expect(result).to be_valid, result.to_message
end
```

`required` means that a JSON key must be present, whereas ActiveModel's `presence`
validator also rejects blank values (including `false`). For APIs where those
semantics are intentionally different, pass `required_validation: :none` and check
required-key behavior separately.

## Rake task

The gem provides `structured_params:openapi:drift_check` in Rails applications.
The task automatically checks classes selected by `parameter_class_filter`, so a
new `Api::*Params` class needs no registration. Use the Registry only for an
exceptional component name or property mapping; explicit registrations override
auto-discovery for the same class.

```ruby
StructuredParams::OpenApi::Registry.register(
  LegacyUserParams,
  schema: 'LegacyCreateUserRequest'
)
```

Run it in CI with:

```sh
bundle exec rake structured_params:openapi:drift_check
```

The current scope deliberately skips `oneOf`, `anyOf`, `allOf`, multiple-type
schemas, and external references. Skips are reported in `result.skipped` so they
remain visible for manual review without being reported as a false type match.
