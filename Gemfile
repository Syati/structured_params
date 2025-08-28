# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

version = ENV['RAILS_VERSION'] || '8.0'

gem_version = "~> #{version}.0"
gem 'actionpack', gem_version
gem 'activemodel', gem_version

group :development, :test do
  gem 'rake', '~> 13.0'
  gem 'rbs-inline', require: false
  gem 'rspec', '~> 3.0'
  gem 'rubocop'
  gem 'rubocop-rake', require: false
  gem 'rubocop-rbs_inline', require: false
  gem 'rubocop-rspec', require: false
  gem 'steep', require: false
end

group :test do
  gem 'rspec-parameterized'
end
