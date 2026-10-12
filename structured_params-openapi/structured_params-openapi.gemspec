# frozen_string_literal: true
# rbs_inline: enabled

require_relative 'lib/structured_params/openapi/version'

Gem::Specification.new do |spec|
  spec.name = 'structured_params-openapi'
  spec.version = StructuredParams::OpenAPI::VERSION
  spec.authors = ['Mizuki Yamamoto']
  spec.email = ['mizuki-y@syati.info']

  spec.summary = 'OpenAPI drift check for StructuredParams.'
  spec.description = (
    'Detects differences between OpenAPI request schemas and StructuredParams classes, ' \
      'with a Rake task for CI, JSON Pointer and component naming conventions, and ' \
      'support for several OpenAPI documents.'
  )
  spec.homepage = 'https://github.com/Syati/structured_params'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.2.0'
  spec.require_paths = ['lib']
  spec.files = Dir[
    'LICENSE.txt',
    'README*.md',
    'CHANGELOG.md',
    'docs/**/*.md',
    'lib/**/*.rb',
    'lib/tasks/**/*.rake',
    'sig/**/*.rbs'
  ]

  spec.metadata = {
    'homepage_uri' => 'https://github.com/Syati/structured_params/tree/main/structured_params-openapi#readme',
    'changelog_uri' => 'https://github.com/Syati/structured_params/blob/main/structured_params-openapi/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/Syati/structured_params/issues',
    'source_code_uri' => 'https://github.com/Syati/structured_params/tree/main/structured_params-openapi',
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'structured_params', '>= 0.9.5'
end
