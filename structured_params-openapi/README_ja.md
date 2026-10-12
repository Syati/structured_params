# structured_params-openapi

[English](README.md) | 日本語

[StructuredParams](https://github.com/Syati/structured_params) 用の OpenAPI drift check です。
OpenAPI のリクエスト schema と `StructuredParams::Params` クラスの差分を検出し、片方だけが
変更されて乖離することを防ぎます。

## インストール

```ruby
# Gemfile
gem 'structured_params-openapi'
```

Bundler が自動で require します(`structured_params/openapi`)。Rails アプリケーションでは、
Rake タスク `structured_params:openapi:drift_check` も自動で登録されます。

## 使い方

```ruby
# config/initializers/structured_params_openapi.rb
StructuredParams::OpenAPI.configure do |config|
  config.document = Rails.root.join('docs/api/openapi.yaml').to_s
  config.parameter_class_filter = ->(klass) { klass.name&.start_with?('Api::') }
end
```

```sh
bundle exec rake structured_params:openapi:drift_check
```

命名規則、複数の OpenAPI ファイル、検出結果の無視、対応している schema の機能については、
[ガイド](docs/drift-check_ja.md)を参照してください。
