# Changelog

## [0.1.0] - 2026-10-14

## structured_params-openapi 0.1.0

First release of the OpenAPI drift check for StructuredParams, extracted into its own gem.

### Features
- Compares OpenAPI request schemas with `StructuredParams::Params` classes: properties, scalar and nested object/array types, and `required` against presence validation.
- `structured_params:openapi:drift_check` Rake task with automatic class discovery (`parameter_class_filter`) and explicit mappings (`Registry.register`).
- Component naming: default convention, `schema_name_resolver`, `schema:` / `pointer:`.
- Several OpenAPI files: `document_resolver` and `Registry.register(openapi:)`.
- `ignore_drift(path:, kind:, parameter_class:)` to accept known findings.
- OpenAPI 3.1 nullable forms and scalar `oneOf`/`anyOf` are compared; missing schemas and broken `$ref`s are errors; skipped checks are printed and `STRUCTURED_PARAMS_STRICT=1` fails on them.
- English and Japanese guides.

### Installation
```ruby
gem 'structured_params-openapi'
```
Requires `structured_params >= 0.9.5`.

