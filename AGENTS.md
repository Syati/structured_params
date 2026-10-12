# AGENTS.md

このリポジトリで作業するエージェント向けの運用ガイドです。変更前に全体像を確認し、最小差分で修正してください。

## プロジェクト概要

- `structured_params` は Rails 向けの型付きパラメータ/フォームオブジェクト用 gem です。
- このリポジトリには 2 つの gem があり、それぞれ独自のフォルダを持ちます。コア gem は `structured_params/`、OpenAPI drift check は `structured_params-openapi/` です。
- コア実装は `structured_params/lib/structured_params/` 配下にあります。
- テストは RSpec、Lint は RuboCop、型検査は Steep を使います。
- RBS シグネチャは `rbs-inline` から生成されます。

## 主要ディレクトリ

- `structured_params/`: コア gem。`lib/`・`sig/`・`spec/`・`docs/`・`structured_params.gemspec`・`CHANGELOG.md` を持ちます。
- `structured_params-openapi/`: OpenAPI drift check の別 gem。同じ構成の独自の `lib/`・`sig/`・`spec/`・`docs/` と gemspec を持ちます。
- リポジトリ直下: `README.md`、`Gemfile`、`Rakefile`、`Steepfile`、`lefthook.yml`、RuboCop 設定など、両方の gem に共通のもの。

- `structured_params/lib/structured_params.rb`: エントリーポイント
- `structured_params/lib/structured_params/params.rb`: コアの `Params` 実装
- `structured_params/lib/structured_params/type/`: `array` / `object` 型ハンドラ
- `structured_params/spec/`: RSpec テスト
- `structured_params/docs/`: 利用者向けドキュメント
- `structured_params/sig/`: `rbs-inline` により生成された RBS

## セットアップと実行

初回セットアップ:

```bash
bin/setup
```

通常の確認:

```bash
bundle exec rspec
bundle exec rubocop
bundle exec steep check
```

Ruby 3.2 系では `steep` や `.rubocop_rbs.yml` 前提のチェックが使えない場合があります。`Rakefile` は Ruby 3.3+ でのみ `steep` をデフォルトタスクに含めます。

個別実行例:

```bash
(cd structured_params && bundle exec rspec spec/params_spec.rb)
bundle exec rubocop structured_params/lib/structured_params/params.rb
```

## 変更時のルール

- `sig/**/*.rbs` は手編集しないでください。必要なら各 gem のフォルダ(`structured_params/` など)で `bundle exec rbs-inline --output=sig lib/**/*.rb` を実行して再生成します。
- Ruby メソッドの型注釈は `rbs-inline` の `method_type_signature` スタイルを使ってください。
- インスタンス変数の型注釈は `# @rbs` コメントを使ってください。
- 既存の公開 API を変える場合は、README と `docs/` の整合も確認してください。
- Strong Parameters、ネストした object/array、エラー整形は回帰しやすいので重点的に確認してください。

## テスト方針

- 振る舞い変更には RSpec を追加または更新してください。
- 既存 spec のスタイルに合わせ、必要に応じて `structured_params/spec/factories/` と `structured_params/spec/support/` を再利用してください。
- 修正が型やシリアライズ、permit 生成に関わる場合は、関連 spec を広めに実行してください。

## コミット前チェック

`lefthook.yml` によりコミット前に以下が走ります。

- 各 gem のフォルダでの `bundle exec rbs-inline --output=sig lib/**/*.rb`(`structured_params/` と `structured_params-openapi/`)
- `bundle exec rubocop`
- 各 gem のフォルダでの `bundle exec rspec`(`structured_params/` と `structured_params-openapi/`)
- `bundle exec steep check`

フックで失敗しない状態まで揃えてから完了扱いにしてください。

## ドキュメント更新の目安

以下を変えた場合はドキュメント更新を検討してください。

- 新しい attribute オプションや型の追加
- permit 挙動の変更
- エラーフォーマットやバリデーション挙動の変更
- Rails / Ruby サポート範囲の変更

利用者向け概要は `README.md`、詳細仕様は `structured_params/docs/*.md`、日本語 README が必要なら `README_ja.md` も更新します。
