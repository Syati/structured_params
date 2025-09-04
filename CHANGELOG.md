# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2025-09-04

**Full Changelog**: https://github.com/Syati/structured_params/compare/v0.1.3...v0.1.4



### Fixed
- Fixed error key consistency issue where `errors.import` was using string keys instead of symbol keys
- Updated method names and comments to use consistent 'structured' terminology instead of 'nested'
- Fixed type annotations for method calls requiring explicit parameters

### Changed
- Renamed methods for better consistency:
  - `each_nested_attribute_name` → `each_structured_attribute_name`
  - `validate_nested_parameters` → `validate_structured_parameters`
  - `import_nested_errors` → `import_structured_errors`
  - `serialize_nested_value` → `serialize_structured_value`
- Updated documentation to reflect current `:object` and `:array` types instead of `:nested`

## [0.1.0] - Initial Release

### Added
- Initial implementation of StructuredParams with support for structured objects and arrays
- ActiveModel integration for validation and attributes
- Strong Parameters compatibility
- Type system with Object and Array types
- RBS type definitions
- Comprehensive test suite
