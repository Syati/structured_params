# Changelog

## [0.3.0] - 2025-09-06

## What's Changed
* Expand Rails compatibility to support Rails 7.2+ through 8.x


**Full Changelog**: https://github.com/Syati/structured_params/compare/v0.2.0...v0.3.0

## [0.2.1] - 2025-09-06

## What's Changed
* Bump version to 0.2.0 by @Syati in https://github.com/Syati/structured_params/pull/2
* Update project documentation by @Syati in https://github.com/Syati/structured_params/pull/3
* Add comparison document for StructuredParams and similar gems by @Syati in https://github.com/Syati/structured_params/pull/4
* Update Gemfile and CI configuration to support multiple Rails versions by @Syati in https://github.com/Syati/structured_params/pull/5
* Refactor release workflow to update version and CHANGELOG handling by @Syati in https://github.com/Syati/structured_params/pull/6


**Full Changelog**: https://github.com/Syati/structured_params/compare/v0.2.0...v0.2.1

## What's Changed
* Bump version to 0.2.0 by @Syati in https://github.com/Syati/structured_params/pull/2
* Update project documentation by @Syati in https://github.com/Syati/structured_params/pull/3
* Add comparison document for StructuredParams and similar gems by @Syati in https://github.com/Syati/structured_params/pull/4
* Update Gemfile and CI configuration to support multiple Rails versions by @Syati in https://github.com/Syati/structured_params/pull/5
* Refactor release workflow to update version and CHANGELOG handling by @Syati in https://github.com/Syati/structured_params/pull/6


**Full Changelog**: https://github.com/Syati/structured_params/compare/v0.2.0...v0.2.1

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-09-05

## What's Changed
* Improve error handling and serialization features by @Syati in https://github.com/Syati/structured_params/pull/1


**Full Changelog**: https://github.com/Syati/structured_params/compare/v0.1.4...v0.2.0



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
