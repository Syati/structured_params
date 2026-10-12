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
`Param`, `Params`, `Parameter`, `Parameters`, or `Form` are removed. Override the
convention globally when necessary.

```ruby
StructuredParams::OpenApi.configure do |config|
  config.schema_name_resolver = ->(parameter_class) do
    "#{parameter_class.name.demodulize.delete_suffix('Params')}Request"
  end
end
```

For an exceptional class, pass its component name as `schema:`. It also accepts a
JSON Pointer (`'/components/schemas/CreateUserRequest'`, `'#/…'`) or an inline Hash.
`pointer:` selects a pointer explicitly, and `openapi:` overrides the configured
document for one call (a file path or a Hash).

```ruby
StructuredParams::OpenApi::DriftCheck.call(
  parameter_class: CreateUserParams,
  schema: 'CreateUserRequest'
)
```

Scalar types are compared as follows:

| Schema `type` | Accepted attribute types |
|---------------|--------------------------|
| `string`      | `:string`, `:date`, `:datetime`, `:time` (`format` is not inspected) |
| `integer`     | `:integer`, `:big_integer` |
| `number`      | `:float`, `:decimal` |
| `boolean`, `object`, `array` | the same type |

A schema with neither `type` nor `properties` (for example an enum-only schema) is
reported as a `type_mismatch`.

The checker compares schema properties with `attribute` declarations, scalar and
nested object/array types, and schema `required` properties with unconditional
`validates ..., presence: true` declarations ("unconditional" means none of the
`if:`, `unless:`, `on:`, `allow_nil:` or `allow_blank:` options). Use `property_names` when the JSON
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

## Ignoring a specific finding

`required_validation: :none` and the Registry both operate on a whole class, so they
aren't precise enough to accept one known finding while still checking everything else
at that path. For that, configure an ignore rule instead:

```ruby
StructuredParams::OpenApi.configure do |config|
  config.ignore_drift(path: 'wallet_information.wallet_type', kind: :missing_presence_validation)
end
```

This applies wherever that path occurs, including once per parent class for a nested
object reused by several top-level parameter classes. Omit `kind:` to ignore every
error kind at that path. Pass `parameter_class:` (a class or its name) to limit a rule
to one class. Valid kinds are `missing_attribute`, `unexpected_attribute`,
`missing_presence_validation`, `type_mismatch`, `missing_schema` and
`unresolved_reference`; anything else raises `ArgumentError`. Paths use attribute names
joined with `.`, with `[]` for array items (for example `items[].sku`), and a schema
that cannot be found at all is reported at `(root)`. Skips are never ignored. Ignored findings move to `result.ignored` instead of
`result.errors`, so `valid?` treats them as resolved and they don't appear in
`to_message` — but they stay available on the result object for anyone who wants to
audit what's being suppressed and why, rather than disappearing silently.

## Rake task

The gem provides `structured_params:openapi:drift_check` in Rails applications.
The task automatically checks classes selected by `parameter_class_filter` (without a
filter, only registered classes are checked, and the task warns when nothing was
checked), so a new `Api::*Params` class needs no registration. Anonymous classes are
never auto-discovered, which is also why the filter example guards with `name&.`. Use the Registry only for an
exceptional component name or property mapping; explicit registrations override
auto-discovery for the same class.

```ruby
StructuredParams::OpenApi::Registry.register(
  LegacyUserParams,
  schema: 'LegacyCreateUserRequest'
)
```

`parameter_class` may also be a class name String, which is resolved lazily when
the task runs. This is useful for registering from a plain `config/initializers/*.rb`
file, where Rails hasn't finished setting up autoloading yet and referencing the
class constant directly would raise `NameError`.

```ruby
StructuredParams::OpenApi::Registry.register(
  'LegacyUserParams',
  schema: 'LegacyCreateUserRequest'
)
```

Run it in CI with:

```sh
bundle exec rake structured_params:openapi:drift_check
```

The current scope deliberately skips `oneOf`, `anyOf`, multi-entry `allOf`, schemas
with a `type` array (every OpenAPI 3.1 nullable such as `[string, 'null']`; 3.0
`nullable: true` is compared normally), and external references. A single-entry
`allOf` is treated as the schema it wraps, as TypeSpec emits for `$ref` plus a
`description`. Recursive schemas are compared once per ancestor chain; the repeated visit
is dropped silently.

Skips never fail a run, but they are not silent: the Rake task prints every skipped
and ignored entry with a summary line, and `result.skipped` / `result.to_report` expose
them in RSpec. Set `STRUCTURED_PARAMS_STRICT=1` (or pass `strict: true` to
`Registry.check_all!`) to fail on skipped checks too.

A class whose resolved schema name has no matching component is reported as a
`missing_schema` error, as is a dangling or circular local `$ref`
(`unresolved_reference`), so a renamed component or a typo cannot silently drop
coverage. For a class that intentionally has no schema (for example one backed by query
parameters), ignore it explicitly:

```ruby
StructuredParams::OpenApi.configure do |config|
  config.ignore_drift(path: '(root)', kind: :missing_schema, parameter_class: 'SearchParams')
end
```

`result.to_message` is prefixed with the checked class's name, so `check_all!`'s
combined `DriftError` message reads as one block per class instead of a flat,
unattributed list of paths. A later registration for the same class replaces an earlier
one.
