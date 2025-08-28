# frozen_string_literal: true

source "https://rubygems.org"

gemspec

version = ENV["RAILS_VERSION"] || "8.0"

if version == "master"
  git "https://github.com/rails/rails.git" do
    gem "actionpack"
    gem "activemodel"
  end
else
  gem_version = "~> #{version}.0"
  gem "actionpack", gem_version
  gem "activemodel", gem_version
end

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rspec", "~> 3.0"
  gem "rubocop"
  gem "steep", require: false
end
