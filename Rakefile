# frozen_string_literal: true
# rbs_inline: enabled

require 'bundler/gem_helper'
require 'rubocop/rake_task'

# The repository holds two gems, each in its own directory with its own spec suite.
# `rake build`/`install`/`release` act on the core gem; build the others from their directory.
GEM_DIRS = %w[structured_params structured_params-openapi].freeze #: Array[String]

Bundler::GemHelper.install_tasks(dir: 'structured_params', name: 'structured_params')

GEM_DIRS.each do |gem_dir|
  desc "Run the #{gem_dir} specs"
  task "spec:#{gem_dir}" do
    Dir.chdir(gem_dir) { sh 'bundle exec rspec' }
  end
end

desc 'Run the specs of every gem'
task spec: GEM_DIRS.map { |gem_dir| "spec:#{gem_dir}" }

# Use RBS Inline configuration for Ruby 3.3+
rubocop_config = if RUBY_VERSION >= '3.3.0'
                   '.rubocop_rbs.yml'
                 else
                   '.rubocop.yml'
                 end

RuboCop::RakeTask.new do |task|
  task.options = ['--config', rubocop_config]
end

# Steep is only available for Ruby 3.3+
default_tasks = %i[spec rubocop]

if RUBY_VERSION >= '3.3.0'
  require 'steep/rake_task'
  Steep::RakeTask.new
  default_tasks << :steep
end

task default: default_tasks
