# OpenAPI Drift Check

[English](drift-check.md) | 日本語

OpenAPI のリクエスト schema と `StructuredParams::Params` クラスの差分を検出し、
片方だけが変更されて乖離することを防ぎます。

## 目次

- [用語](#用語)
- [クイックスタート](#クイックスタート)
- [クラスと schema の対応付け](#クラスと-schema-の対応付け)
  - [既定の命名規則](#既定の命名規則)
  - [命名規則を変更する](#命名規則を変更する)
  - [特定のクラスだけ例外にする](#特定のクラスだけ例外にする)
- [比較する内容](#比較する内容)
  - [スカラー型](#スカラー型)
  - [attribute と必須 property](#attribute-と必須-property)
  - [property 名の対応](#property-名の対応)
- [RSpec で使う](#rspec-で使う)
- [特定の検出結果を無視する](#特定の検出結果を無視する)
- [Rake タスクと Registry](#rake-タスクと-registry)
  - [自動検出](#自動検出)
  - [例外を登録する](#例外を登録する)
  - [複数の OpenAPI ファイル](#複数の-openapi-ファイル)
  - [CI で実行する](#ci-で実行する)
- [対象範囲、skip、schema の欠落](#対象範囲skipschema-の欠落)

## 用語

このドキュメントで **component** と呼ぶのは、OpenAPI ドキュメントの
`components.schemas` 配下にある、名前付きの schema のことです。各 `Params` クラスは、
名前で見つけた 1 つの component と照合されます(たとえば `CreateUserParams` →
`CreateUser`)。

```yaml
# openapi.yml
components:
  schemas:
    CreateUser:        # <- これが「component」(JSON Pointer は #/components/schemas/CreateUser)
      type: object
      properties:
        name: { type: string }
```

## クイックスタート

initializer を追加し、必要な部分だけ残してください。この例の OpenAPI ドキュメントは
TypeSpec から生成されているため、component 名は `V1.Orders.CreateRequest` のような形で、
クラス名は `Api::V1::Orders::CreateRequestParameter` のような形です。

```ruby
# config/initializers/structured_params_openapi.rb
StructuredParams::OpenAPI.configure do |config|
  # 必須: OpenAPI ドキュメントと、検査するクラス
  config.document = Rails.root.join('docs/api/openapi.yaml').to_s
  config.parameter_class_filter = ->(klass) { klass.name&.start_with?('Api::') }

  # component 名が既定の規則(CreateUserParams -> CreateUser)と異なる場合だけ:
  # Api::V1::Orders::CreateRequestParameter -> "V1.Orders.CreateRequest"
  config.schema_name_resolver = lambda do |klass|
    klass.name.delete_prefix('Api::').delete_suffix('Parameter').gsub('::', '.')
  end

  # schema があるはずだがまだないクラスがある場合だけ:
  # 失敗にせず、記録だけ残す
  %w[
    Api::V1::Reports::ExportRequestParameter
    Api::V1::Reports::SummaryRequestParameter
  ].each do |name|
    config.ignore_drift(kind: :missing_schema, parameter_class: name)
  end
end

# 上の規則に従わない component 名を持つクラスがある場合だけ
{
  'Api::V1::Orders::KonbiniRequestParameter' => 'V1.Orders.CreateKonbiniRequest',
  'Api::V1::Orders::BankTransferRequestParameter' => 'V1.Orders.CreateBankTransferRequest'
}.each do |parameter_class, schema|
  StructuredParams::OpenAPI::Registry.register(parameter_class, schema: schema)
end
```

- `parameter_class_filter` は検査するクラスを選びます。新しい `Api::*` クラスは、登録なしで
  対象になります。
- `schema_name_resolver` は、1 つの規則で全クラスを component に対応付けます。
- `ignore_drift` は、まだ schema がないクラスを記録します。Rake の出力には一覧表示され
  続けます。検査する予定のないクラスは、filter から外すほうが適切です
  ([対象範囲、skip、schema の欠落](#対象範囲skipschema-の欠落)を参照)。
- `Registry.register` は、命名の規則に合わない少数のクラスを個別に対応付けます。

あとは Rake タスクを実行すると、直すべき残りが分かります。

```sh
bundle exec rake structured_params:openapi:drift_check
```

## クラスと schema の対応付け

### 既定の命名規則

既定では、`CreateUserParams` を `#/components/schemas/CreateUser` に対応付けます。
クラスの namespace と、末尾の `Param`、`Params`、`Parameter`、`Parameters`、`Form` を
取り除いた名前が component 名になります。

### 命名規則を変更する

component の命名規則が異なる場合は、`schema_name_resolver` で全体の規則を変更します。
たとえば OpenAPI 側で、`Api::V1::CreateUserParams` と `Api::V2::CreateUserParams` に
対応する component が `V1CreateUserRequest` と `V2CreateUserRequest` という名前の場合は、
次のようにします。

```yaml
# openapi.yml
components:
  schemas:
    V1CreateUserRequest:   # <- 既定の規則では CreateUser を探してしまう
      type: object
      properties:
        name: { type: string }
    V2CreateUserRequest: ...
```

```ruby
StructuredParams::OpenAPI.configure do |config|
  config.schema_name_resolver = ->(parameter_class) do
    # Api::V1::CreateUserParams -> "V1CreateUser" -> "V1CreateUserRequest"
    name = parameter_class.name.delete_prefix('Api::').delete_suffix('Params').gsub('::', '')
    "#{name}Request"
  end
end
```

resolver が返すのは component 名で、すべてのクラスで既定の規則の代わりに使われます。
この例が取り除くのは `Params` だけなので、`CreateUserForm` は `CreateUserFormRequest`
になります。

返す名前には namespace を残してください。残さない(たとえば `demodulize` で外す)と、
`Api::V1::CreateUserParams` も `Api::V2::CreateUserParams` も存在しない
`CreateUserRequest` を探してしまい、`missing_schema` になります。バージョンごとに
OpenAPI ファイル自体が分かれている場合は、component 名はそのままにして、
`document_resolver` でファイルを切り替えます
([複数の OpenAPI ファイル](#複数の-openapi-ファイル)を参照)。

### 特定のクラスだけ例外にする

例外的なクラスには、`schema:` で component 名を渡します。JSON Pointer
(`'/components/schemas/CreateUserRequest'`、`'#/…'`)や、インラインの Hash も渡せます。
`pointer:` で Pointer を明示でき、`openapi:` で 1 回の呼び出しに限って設定済みの
ドキュメントを上書きできます(ファイルパスまたは Hash)。

```ruby
StructuredParams::OpenAPI::DriftCheck.call(
  parameter_class: CreateUserParams,
  schema: 'CreateUserRequest'
)
```

## 比較する内容

### スカラー型

| schema の `type` | 許容する attribute の型 |
|------------------|--------------------------|
| `string`         | `:string`、`:date`、`:datetime`、`:time`(`format` は見ません) |
| `integer`        | `:integer`、`:big_integer` |
| `number`         | `:float`、`:decimal` |
| `boolean`、`object`、`array` | 同じ型 |

`type` も `properties` もない schema(たとえば enum だけの schema)は、
`type_mismatch` として報告されます。ネストした object と array の型は再帰的に比較します。

### attribute と必須 property

schema の property は `attribute` 宣言と比較します。

schema の `required` は presence 検証と比較しますが、この対応は近似です。OpenAPI の
`required` が意味するのは「キーが存在すること」だけです。Rails では、キーが無い場合も値が
`nil` の場合も、属性は `nil` になります。そのため「キーが存在する」ことを表現できる
バリデータはなく、`presence`、`allow_nil`、`allow_blank` のどれが意図なのかも分かりません。
そこでこのチェックは、無条件の `validates ..., presence: true` を代わりの目安として使います
(「無条件」とは、`if:`、`unless:`、`on:`、`allow_nil:`、`allow_blank:` のいずれも指定されて
いないことです)。

schema が null を許す required の property(`nullable: true`、`'null'` を含む `type` 配列、
`null` を選択肢に持つ `oneOf`/`anyOf`)には、`presence` は不要です。`presence` を付けると、
契約が許している null を拒否してしまうため、報告されません。

これらのオプションが付いた `presence` は、キーが無くても通る可能性があるため、`required`
を満たすか確認できず、`missing_presence_validation` として報告されます。これは必ずしも
バグではありません。Ruby 側が意図的な書き方なら、
[`ignore_drift`](#特定の検出結果を無視する)で property ごとに許容してください。`presence`
が API 全体にとって厳しすぎる場合(`required` が許す `false` や `""` も拒否します)は、
`required_validation: :none` を指定し、必須キーの挙動は別に検証してください。

### property 名の対応

JSON の property 名と Ruby の attribute 名が異なる場合は `property_names` を使います。

```ruby
StructuredParams::OpenAPI::DriftCheck.call(
  parameter_class: CreateUserParams,
  property_names: { user_id: 'userId' }
)
```

## RSpec で使う

結果をそのまま失敗メッセージに使うと、CI の失敗に検出した差分がすべて並びます。

```ruby
it 'matches the request schema' do
  result = StructuredParams::OpenAPI::DriftCheck.call(
    parameter_class: CreateUserParams
  )

  expect(result).to be_valid, result.to_message
end
```

## 特定の検出結果を無視する

`required_validation: :none` と Registry はクラス全体に作用するため、既知の 1 件だけを
許容して、同じパスの他の検査は続けたい場合には粗すぎます。その場合は ignore 規則を
設定します。

```ruby
StructuredParams::OpenAPI.configure do |config|
  config.ignore_drift(path: 'wallet_information.wallet_type', kind: :missing_presence_validation)
end
```

- 規則は、そのパスが現れるすべての場所に適用されます。複数のトップレベルクラスが
  再利用するネストした object では、親クラスごとに 1 回ずつ適用されます。
- `kind:` を省略すると、そのパスのすべてのエラー種別を無視します。指定できる種別は
  `missing_attribute`、`unexpected_attribute`、`missing_presence_validation`、
  `type_mismatch`、`missing_schema`、`unresolved_reference` で、それ以外は
  `ArgumentError` になります。
- `parameter_class:`(クラスまたはその名前)を渡すと、規則を 1 つのクラスに限定できます。
- パスは attribute 名を `.` でつなぎ、配列の要素には `[]` を付けます
  (例: `items[].sku`)。`path:`、`kind:`、`parameter_class:` はどれも規則を絞り込み、
  省略したものは「すべて」に一致しますが、少なくとも 1 つは必要です。schema が見つからない
  場合(`missing_schema`)は、property ではなくクラス全体についての指摘なので、`path:`
  を省略します。
- skip は無視できません。

無視した検出結果は `result.errors` ではなく `result.ignored` に移ります。そのため
`valid?` は解決済みとして扱い、`to_message` にも表示されません。ただし結果オブジェクト
には残るので、何をなぜ抑制しているかを後から確認でき、黙って消えることはありません。

## Rake タスクと Registry

### 自動検出

gem は Rails アプリケーションに `structured_params:openapi:drift_check` を提供します。
このタスクは `parameter_class_filter` で選択されたクラスを自動で検査するため、新しい
`Api::*Params` クラスに登録は不要です。

- filter がなければ登録済みのクラスだけが対象で、何も検査されなかった場合は
  タスクが警告します。
- 無名クラスは自動検出されません。filter の例が `name&.` で守られているのはそのためです。

### 例外を登録する

Registry は、例外的な component 名や property の対応付けが必要な場合にだけ使って
ください。同じクラスに対しては、明示的な登録が自動検出より優先されます。同じクラスを
後から登録すると、先の登録を置き換えます。

```ruby
StructuredParams::OpenAPI::Registry.register(
  LegacyUserParams,
  schema: 'LegacyCreateUserRequest'
)
```

`parameter_class` にはクラス名の文字列も渡せます。この場合はタスクの実行時に解決
されます。Rails の autoload がまだ設定されていない `config/initializers/*.rb` から
登録するときに便利です。クラス定数を直接参照すると `NameError` になるためです。

```ruby
StructuredParams::OpenAPI::Registry.register(
  'LegacyUserParams',
  schema: 'LegacyCreateUserRequest'
)
```

### 複数の OpenAPI ファイル

アプリケーションに複数の OpenAPI ファイルがある場合(たとえば `admin_api.yml` と
`front_api.yml`)は、`document_resolver` を設定すると、自動検出された各クラスを
それぞれのファイルに対して検査できます。`nil` を返したクラスは `config.document` に
フォールバックします。

```ruby
StructuredParams::OpenAPI.configure do |config|
  config.parameter_class_filter = ->(klass) { klass.name&.match?(/\A(AdminApi|FrontApi)::/) }
  config.document_resolver = ->(klass) do
    case klass.name
    when /\AAdminApi::/ then Rails.root.join('openapi/admin_api.yml').to_s
    when /\AFrontApi::/ then Rails.root.join('openapi/front_api.yml').to_s
    end
  end
end
```

個別のクラスには `Registry.register(..., openapi:)`(ファイルパスまたは Hash)で
resolver を上書きできます。どちらもなければ、設定済みの `document` を使います。

```ruby
StructuredParams::OpenAPI::Registry.register(
  AdminUserParams,
  openapi: Rails.root.join('openapi/admin.yml').to_s
)
```

### CI で実行する

```sh
bundle exec rake structured_params:openapi:drift_check
```

skip も失敗扱いにしたい場合は、`STRUCTURED_PARAMS_STRICT=1` を設定します(下記参照)。

## 対象範囲、skip、schema の欠落

通常の schema と同じように扱うもの:

- OpenAPI 3.1 の nullable の書き方: `{type: null}` を選択肢に持つ `oneOf`/`anyOf` と、
  `'null'` を含む `type` 配列(たとえば `[string, 'null']`)。null の選択肢を除くと、
  3.0 の `nullable: true` と同じように比較されます。
- スカラーだけの `oneOf`/`anyOf`(たとえば `string` か `integer`)。attribute がどれか 1 つの
  選択肢に合えば一致します。
- 要素が 1 つだけの `allOf`。TypeSpec が `$ref` に `description` を付けるときに出力する形です。

現在の対象範囲では、次のものを意図的に skip します。

- object の `oneOf`/`anyOf`、複数要素の `allOf`
- null 以外の型を複数持つ `type` 配列
- 外部参照

再帰する schema は、祖先の連鎖ごとに 1 回だけ比較され、繰り返しの訪問は黙って打ち切られます。

skip は実行を失敗させませんが、黙ってもいません。Rake タスクは skip と ignore の
すべての項目をサマリ行とともに表示し、RSpec では `result.skipped` と
`result.to_report` で確認できます。skip も失敗扱いにしたい場合は、
`STRUCTURED_PARAMS_STRICT=1` を設定するか、`Registry.check_all!` に `strict: true` を
渡してください。

解決した schema 名に対応する component がないクラスは、`missing_schema` エラーとして
報告されます。壊れた、または循環するローカルの `$ref` も同様です
(`unresolved_reference`)。component 名の変更や打ち間違いで、検査が黙って外れること
はありません。意図的に schema を持たないクラス(たとえば query parameter が元の
クラス)は、次の 2 通りで扱えます。

- 検査する予定がないなら、`parameter_class_filter` から外します。そのクラスはまったく
  検査されず、記録も残りません。

  ```ruby
  NO_SCHEMA = %w[Api::V1::SearchParams].freeze

  StructuredParams::OpenAPI.configure do |config|
    config.parameter_class_filter = ->(klass) do
      klass.name&.start_with?('Api::') && NO_SCHEMA.exclude?(klass.name)
    end
  end
  ```

- 本来は schema があるはずだが、まだない場合は、そのクラスの指摘を無視します。指摘は
  `result.ignored` に移り、Rake タスクにも一覧表示されるので、後から見直せます。

  ```ruby
  StructuredParams::OpenAPI.configure do |config|
    config.ignore_drift(kind: :missing_schema, parameter_class: 'Api::V1::SearchParams')
  end
  ```

`result.to_message` の先頭には検査したクラス名が付くため、`check_all!` がまとめて
投げる `DriftError` のメッセージは、パスをただ並べたものではなく、クラスごとの
ブロックになります。
