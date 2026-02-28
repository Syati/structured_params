# frozen_string_literal: true
# rbs_inline: enabled

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'

# Use RBS Inline configuration only for Ruby 3.3+
rubocop_config = if RUBY_VERSION >= '3.3.0'
                   '.rubocop_rbs.yml'
                 else
                   '.rubocop.yml'
                 end

RuboCop::RakeTask.new do |task|
  task.options = ['--config', rubocop_config]
end

# Steep is only available for Ruby 3.3+
default_tasks = [:spec, :rubocop]

if RUBY_VERSION >= '3.3.0'
  require 'steep/rake_task'
  Steep::RakeTask.new
  default_tasks << :steep
end

task default: default_tasks
