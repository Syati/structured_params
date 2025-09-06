# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# Allow testing different Rails versions via environment variable
rails_version = ENV['RAILS_VERSION'] || '~> 8.0.0'

if rails_version.start_with?('~>')
  # Version constraint specified (e.g., "~> 7.2.0")
  gem 'actionpack', rails_version
  gem 'activemodel', rails_version
else
  # Legacy format support (e.g., "7.2")
  gem_version = "~> #{rails_version}.0"
  gem 'actionpack', gem_version
  gem 'activemodel', gem_version
end

group :development, :test do
  gem 'factory_bot'
  gem 'lefthook', require: false
  gem 'rake', '~> 13.0'
  gem 'rbs-inline', require: false
  gem 'rspec', '~> 3.0'
  gem 'rspec-parameterized'
  gem 'rubocop'
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rake', require: false
  gem 'rubocop-rbs_inline', require: false
  gem 'rubocop-rspec', require: false
  gem 'steep', require: false
end
