# frozen_string_literal: true

require_relative 'lib/structured_params/version'

Gem::Specification.new do |spec|
  spec.name = 'structured_params'
  spec.version = StructuredParams::VERSION
  spec.authors = ['Mizuki Yamamoto']
  spec.email = ['mizuki-y@syati.info']

  spec.summary = 'StructuredParams allows you to validate pass parameter.'
  spec.description = ''
  spec.homepage = 'https://github.com/Syati/structured_params'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'
  spec.require_paths = ['lib']
  spec.files = Dir[
    'LICENSE.txt',
    'CHANGELOG.md',
    'lib/**/*.rb',
    'sig/**/*.rbs'
  ]

  spec.metadata = {
    'homepage_uri' => 'https://github.com/Syati/structured_params#readme',
    'changelog_uri' => 'https://github.com/Syati/structured_params/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/Syati/structured_params/issues',
    'source_code_uri' => 'https://github.com/Syati/structured_params',
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'actionpack', '>= 7.2', '< 9.0'
  spec.add_dependency 'activemodel', '>= 7.2', '< 9.0'
end
