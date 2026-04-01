# AGENTS.md

このリポジトリで作業するエージェント向けの運用ガイドです。変更前に全体像を確認し、最小差分で修正してください。

## プロジェクト概要

- `structured_params` は Rails 向けの型付きパラメータ/フォームオブジェクト用 gem です。
- コア実装は `lib/structured_params/` 配下にあります。
- テストは RSpec、Lint は RuboCop、型検査は Steep を使います。
- RBS シグネチャは `rbs-inline` から生成されます。

## 主要ディレクトリ

- `lib/structured_params.rb`: エントリーポイント
- `lib/structured_params/params.rb`: コアの `Params` 実装
- `lib/structured_params/type/`: `array` / `object` 型ハンドラ
- `spec/`: RSpec テスト
- `docs/`: 利用者向けドキュメント
- `sig/`: `rbs-inline` により生成された RBS

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
bundle exec rspec spec/params_spec.rb
bundle exec rubocop lib/structured_params/params.rb
```

## 変更時のルール

- `sig/**/*.rbs` は手編集しないでください。必要なら `bundle exec rbs-inline --output=sig lib/**/*.rb` で再生成します。
- Ruby メソッドの型注釈は `rbs-inline` の `method_type_signature` スタイルを使ってください。
- インスタンス変数の型注釈は `# @rbs` コメントを使ってください。
- 既存の公開 API を変える場合は、README と `docs/` の整合も確認してください。
- Strong Parameters、ネストした object/array、エラー整形は回帰しやすいので重点的に確認してください。

## テスト方針

- 振る舞い変更には RSpec を追加または更新してください。
- 既存 spec のスタイルに合わせ、必要に応じて `spec/factories/` と `spec/support/` を再利用してください。
- 修正が型やシリアライズ、permit 生成に関わる場合は、関連 spec を広めに実行してください。

## コミット前チェック

`lefthook.yml` によりコミット前に以下が走ります。

- `bundle exec rbs-inline --output=sig lib/**/*.rb`
- `bundle exec rubocop`
- `bundle exec rspec`
- `bundle exec steep check`

フックで失敗しない状態まで揃えてから完了扱いにしてください。

## ドキュメント更新の目安

以下を変えた場合はドキュメント更新を検討してください。

- 新しい attribute オプションや型の追加
- permit 挙動の変更
- エラーフォーマットやバリデーション挙動の変更
- Rails / Ruby サポート範囲の変更

利用者向け概要は `README.md`、詳細仕様は `docs/*.md`、日本語 README が必要なら `README_ja.md` も更新します。
