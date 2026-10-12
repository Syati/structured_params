# OpenAPI Drift Check

English | [日本語](openapi-drift-check_ja.md)

Detects differences between OpenAPI request schemas and `StructuredParams::Params`
classes, so a change on one side cannot silently diverge from the other.

## Table of contents

- [Terms](#terms)
- [Quick start](#quick-start)
- [Matching classes to schemas](#matching-classes-to-schemas)
  - [Default naming convention](#default-naming-convention)
  - [Custom naming convention](#custom-naming-convention)
  - [Exceptions for a single class](#exceptions-for-a-single-class)
- [What is compared](#what-is-compared)
  - [Scalar types](#scalar-types)
  - [Attributes and required properties](#attributes-and-required-properties)
  - [Property names](#property-names)
- [Using it in RSpec](#using-it-in-rspec)
- [Ignoring a specific finding](#ignoring-a-specific-finding)
- [Rake task and Registry](#rake-task-and-registry)
  - [Auto-discovery](#auto-discovery)
  - [Registering exceptions](#registering-exceptions)
  - [Multiple OpenAPI files](#multiple-openapi-files)
  - [Running in CI](#running-in-ci)
- [Scope, skips and missing schemas](#scope-skips-and-missing-schemas)

## Terms

In this guide, a **component** means a named schema under `components.schemas` in the
OpenAPI document. Each `Params` class is checked against one component, found by name
(for example `CreateUserParams` → `CreateUser`).

```yaml
# openapi.yml
components:
  schemas:
    CreateUser:        # <- a "component" (its JSON Pointer is #/components/schemas/CreateUser)
      type: object
      properties:
        name: { type: string }
```

## Quick start

Add an initializer and keep only the parts you need. The OpenAPI document here is
generated from TypeSpec, so its components are named like `V1.Orders.CreateRequest`, for
classes named like `Api::V1::Orders::CreateRequestParameter`.

```ruby
# config/initializers/structured_params_openapi.rb
StructuredParams::OpenApi.configure do |config|
  # Required: the OpenAPI document and the classes to check.
  config.document = Rails.root.join('docs/api/openapi.yaml').to_s
  config.parameter_class_filter = ->(klass) { klass.name&.start_with?('Api::') }

  # Only if your component names differ from the default convention
  # (CreateUserParams -> CreateUser):
  # Api::V1::Orders::CreateRequestParameter -> "V1.Orders.CreateRequest"
  config.schema_name_resolver = lambda do |klass|
    klass.name.delete_prefix('Api::').delete_suffix('Parameter').gsub('::', '.')
  end

  # Only for classes that should have a schema but do not yet:
  # record them instead of failing.
  %w[
    Api::V1::Reports::ExportRequestParameter
    Api::V1::Reports::SummaryRequestParameter
  ].each do |name|
    config.ignore_drift(kind: :missing_schema, parameter_class: name)
  end
end

# Only for classes whose component name does not follow the convention above.
{
  'Api::V1::Orders::KonbiniRequestParameter' => 'V1.Orders.CreateKonbiniRequest',
  'Api::V1::Orders::BankTransferRequestParameter' => 'V1.Orders.CreateBankTransferRequest'
}.each do |parameter_class, schema|
  StructuredParams::OpenApi::Registry.register(parameter_class, schema: schema)
end
```

- `parameter_class_filter` selects the classes to check, so a new `Api::*` class is
  picked up without registration.
- `schema_name_resolver` maps every class to its component by one rule.
- `ignore_drift` records a class that has no schema yet, and it stays listed in the Rake
  output. A class that is never meant to be checked is better left out of the filter
  (see [Scope, skips and missing schemas](#scope-skips-and-missing-schemas)).
- `Registry.register` covers the few classes that break the naming rule.

Then run the Rake task to see what is left to fix:

```sh
bundle exec rake structured_params:openapi:drift_check
```

## Matching classes to schemas

### Default naming convention

By default, `CreateUserParams` is matched with `#/components/schemas/CreateUser`: the
class's namespace and a trailing `Param`, `Params`, `Parameter`, `Parameters`, or `Form`
are removed.

### Custom naming convention

If your components follow a different naming convention, override it globally with
`schema_name_resolver`. For example, when the OpenAPI document names the components
for `Api::V1::CreateUserParams` and `Api::V2::CreateUserParams` as `V1CreateUserRequest`
and `V2CreateUserRequest`:

```yaml
# openapi.yml
components:
  schemas:
    V1CreateUserRequest:   # <- the default convention would look for CreateUser
      type: object
      properties:
        name: { type: string }
    V2CreateUserRequest: ...
```

```ruby
StructuredParams::OpenApi.configure do |config|
  config.schema_name_resolver = ->(parameter_class) do
    # Api::V1::CreateUserParams -> "V1CreateUser" -> "V1CreateUserRequest"
    name = parameter_class.name.delete_prefix('Api::').delete_suffix('Params').gsub('::', '')
    "#{name}Request"
  end
end
```

The resolver returns a component name, which replaces the default convention for every
class. Only the suffix `Params` is removed here, so a `CreateUserForm` would become
`CreateUserFormRequest`.

Keep the namespace in the returned name. If you drop it (for example with `demodulize`),
`Api::V1::CreateUserParams` and `Api::V2::CreateUserParams` both look for
`CreateUserRequest`, which does not exist, and report `missing_schema`. If each version
lives in its own OpenAPI file instead, keep the component name as is and switch files with
`document_resolver` (see [Multiple OpenAPI files](#multiple-openapi-files)).

### Exceptions for a single class

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

## What is compared

### Scalar types

| Schema `type` | Accepted attribute types |
|---------------|--------------------------|
| `string`      | `:string`, `:date`, `:datetime`, `:time` (`format` is not inspected) |
| `integer`     | `:integer`, `:big_integer` |
| `number`      | `:float`, `:decimal` |
| `boolean`, `object`, `array` | the same type |

A schema with neither `type` nor `properties` (for example an enum-only schema) is
reported as a `type_mismatch`. Nested object and array types are compared recursively.

### Attributes and required properties

Schema properties are compared with `attribute` declarations.

Schema `required` is compared with presence validation, and this mapping is only an
approximation. OpenAPI's `required` means one thing: the key must exist. In Rails,
a missing key and a `nil` value both leave the attribute `nil`, so no validator can
express "the key exists", and nothing says whether `presence`, `allow_nil` or
`allow_blank` was intended. The check therefore uses an unconditional
`validates ..., presence: true` as a stand-in ("unconditional" means none of the `if:`,
`unless:`, `on:`, `allow_nil:` or `allow_blank:` options).

A required property that the schema allows to be null (`nullable: true`, a `type` array
including `'null'`, or a `oneOf`/`anyOf` with a `null` option) needs no `presence`, since
`presence` would reject the null the contract permits, so it is not reported.

A `presence` that carries one of those options may let a missing key through, so the
check cannot confirm it satisfies `required` and reports `missing_presence_validation`.
That is not necessarily a bug. When the Ruby side is intentional, accept it per
property with [`ignore_drift`](#ignoring-a-specific-finding). When `presence` is
too strict for the whole API (it also rejects `false` and `""`, which `required` allows),
pass `required_validation: :none` and check required-key behavior separately.

### Property names

Use `property_names` when the JSON property name differs from the Ruby attribute name.

```ruby
StructuredParams::OpenApi::DriftCheck.call(
  parameter_class: CreateUserParams,
  property_names: { user_id: 'userId' }
)
```

## Using it in RSpec

Use the result as the failure message so a CI failure lists every detected difference.

```ruby
it 'matches the request schema' do
  result = StructuredParams::OpenApi::DriftCheck.call(
    parameter_class: CreateUserParams
  )

  expect(result).to be_valid, result.to_message
end
```

## Ignoring a specific finding

`required_validation: :none` and the Registry both operate on a whole class, so they
aren't precise enough to accept one known finding while still checking everything else
at that path. For that, configure an ignore rule instead:

```ruby
StructuredParams::OpenApi.configure do |config|
  config.ignore_drift(path: 'wallet_information.wallet_type', kind: :missing_presence_validation)
end
```

- The rule applies wherever that path occurs, including once per parent class for a
  nested object reused by several top-level parameter classes.
- Omit `kind:` to ignore every error kind at that path. Valid kinds are
  `missing_attribute`, `unexpected_attribute`, `missing_presence_validation`,
  `type_mismatch`, `missing_schema` and `unresolved_reference`; anything else raises
  `ArgumentError`.
- Pass `parameter_class:` (a class or its name) to limit a rule to one class.
- Paths use attribute names joined with `.`, with `[]` for array items (for example
  `items[].sku`). Each of `path:`, `kind:` and `parameter_class:` narrows a rule and an
  omitted one matches everything, but at least one is required. A missing schema
  (`missing_schema`) concerns the whole class rather than a property, so omit `path:`.
- Skips are never ignored.

Ignored findings move to `result.ignored` instead of `result.errors`, so `valid?`
treats them as resolved and they don't appear in `to_message` — but they stay available
on the result object for anyone who wants to audit what's being suppressed and why,
rather than disappearing silently.

## Rake task and Registry

### Auto-discovery

The gem provides `structured_params:openapi:drift_check` in Rails applications. The task
automatically checks classes selected by `parameter_class_filter`, so a new
`Api::*Params` class needs no registration.

- Without a filter, only registered classes are checked, and the task warns when
  nothing was checked.
- Anonymous classes are never auto-discovered, which is also why the filter example
  guards with `name&.`.

### Registering exceptions

Use the Registry only for an exceptional component name or property mapping; explicit
registrations override auto-discovery for the same class, and a later registration for
the same class replaces an earlier one.

```ruby
StructuredParams::OpenApi::Registry.register(
  LegacyUserParams,
  schema: 'LegacyCreateUserRequest'
)
```

`parameter_class` may also be a class name String, which is resolved lazily when the
task runs. This is useful for registering from a plain `config/initializers/*.rb` file,
where Rails hasn't finished setting up autoloading yet and referencing the class
constant directly would raise `NameError`.

```ruby
StructuredParams::OpenApi::Registry.register(
  'LegacyUserParams',
  schema: 'LegacyCreateUserRequest'
)
```

### Multiple OpenAPI files

When an application has several OpenAPI files (for example `admin_api.yml` and
`front_api.yml`), set `document_resolver` so each auto-discovered class is checked
against its own file. Return `nil` to fall back to `config.document`.

```ruby
StructuredParams::OpenApi.configure do |config|
  config.parameter_class_filter = ->(klass) { klass.name&.match?(/\A(AdminApi|FrontApi)::/) }
  config.document_resolver = ->(klass) do
    case klass.name
    when /\AAdminApi::/ then Rails.root.join('openapi/admin_api.yml').to_s
    when /\AFrontApi::/ then Rails.root.join('openapi/front_api.yml').to_s
    end
  end
end
```

For a one-off class, `Registry.register(..., openapi:)` (a file path or Hash) overrides
the resolver. Without either, the configured `document` is used.

```ruby
StructuredParams::OpenApi::Registry.register(
  AdminUserParams,
  openapi: Rails.root.join('openapi/admin.yml').to_s
)
```

### Running in CI

```sh
bundle exec rake structured_params:openapi:drift_check
```

Set `STRUCTURED_PARAMS_STRICT=1` to also fail on skipped checks (see below).

## Scope, skips and missing schemas

Handled as if they were plain schemas:

- OpenAPI 3.1 nullable forms: `oneOf`/`anyOf` with a `{type: null}` option and a `type`
  array with `'null'` (for example `[string, 'null']`). Once the null option is removed
  they are compared like 3.0 `nullable: true`;
- `oneOf`/`anyOf` of plain scalars (for example `string` or `integer`), which match when
  the attribute fits any option;
- a single-entry `allOf`, as TypeSpec emits for `$ref` plus a `description`.

The current scope deliberately skips:

- `oneOf`/`anyOf` of objects, and multi-entry `allOf`;
- a `type` array of several non-null types;
- external references.

Recursive schemas are compared once per ancestor chain; the repeated visit is dropped
silently.

Skips never fail a run, but they are not silent: the Rake task prints every skipped and
ignored entry with a summary line, and `result.skipped` / `result.to_report` expose them
in RSpec. Set `STRUCTURED_PARAMS_STRICT=1` (or pass `strict: true` to
`Registry.check_all!`) to fail on skipped checks too.

A class whose resolved schema name has no matching component is reported as a
`missing_schema` error, as is a dangling or circular local `$ref`
(`unresolved_reference`), so a renamed component or a typo cannot silently drop
coverage. A class that intentionally has no schema (for example one backed by query
parameters) can be handled in two ways:

- If it is never meant to be checked, leave it out of `parameter_class_filter`. The
  class is not checked at all, and nothing is recorded about it.

  ```ruby
  NO_SCHEMA = %w[Api::V1::SearchParams].freeze

  StructuredParams::OpenApi.configure do |config|
    config.parameter_class_filter = ->(klass) do
      klass.name&.start_with?('Api::') && NO_SCHEMA.exclude?(klass.name)
    end
  end
  ```

- If a schema should exist but does not yet, ignore the finding for that class. It moves
  to `result.ignored` and is listed by the Rake task, so it can be revisited later.

  ```ruby
  StructuredParams::OpenApi.configure do |config|
    config.ignore_drift(kind: :missing_schema, parameter_class: 'Api::V1::SearchParams')
  end
  ```

`result.to_message` is prefixed with the checked class's name, so `check_all!`'s
combined `DriftError` message reads as one block per class instead of a flat,
unattributed list of paths.
