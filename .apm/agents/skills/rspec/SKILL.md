---
name: rspec
description: Run and debug RSpec tests for the structured_params gem. Use when adding features, fixing bugs, or validating behavior changes in specs under spec/.
---

# RSpec Skill

Run tests with minimal scope first, then widen only when needed.

## Core Commands

```bash
bundle exec rspec spec/attribute_methods_spec.rb
bundle exec rspec spec/params_spec.rb
bundle exec rspec
```

## Workflow

1. Run the most specific spec file related to the change.
2. If failures include shared behavior, run adjacent spec files.
3. Run full `bundle exec rspec` before finishing if behavior changed broadly.

## Failure Triage

- `NoMethodError` around params fields:
  Check `lib/structured_params/params.rb` and `lib/structured_params/attribute_methods.rb`.
- Nested error path mismatch:
  Check `lib/structured_params/errors.rb` and structured validation behavior.
- Type-cast related mismatch:
  Confirm expected value vs `*_before_type_cast` usage in specs.

## Repository Notes

- Test helpers/classes are loaded from `spec/support/test_classes.rb`.
- Factory objects live under `spec/factories/`.
- This project uses `bundle exec` for all test commands.
