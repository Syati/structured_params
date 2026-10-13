# StructuredParams

[English](README.md) | 日本語

**Rails の型付きパラメータオブジェクトとフォームオブジェクトを提供する gem。**

対応範囲は Ruby `3.2+`、Rails / ActiveModel `7.2` 以上 `9.0` 未満です。

StructuredParams は、以下の課題を解決します：

- **API エンドポイント**: リクエストパラメータの型チェック、バリデーション、型変換
- **フォームオブジェクト**: 複雑なフォーム入力の検証とモデル変換

ActiveModel をベースに、ネストしたオブジェクトや配列も簡潔に扱えます。

## 主な機能

- ✅ **API パラメータバリデーション** - 型安全なリクエスト検証
- ✅ **フォームオブジェクト** - 複雑なフォームロジックをカプセル化
- ✅ **ネスト構造のサポート** - object / array の自動キャスト
- ✅ **Strong Parameters 連携** - permit リストの自動生成
- ✅ **ActiveModel 互換** - バリデーション、シリアライズなど標準機能を利用可能
- ✅ **RBS 型定義** - 型安全な開発体験

## クイックスタート

```ruby
# Gemfile
gem 'structured_params'

# config/initializers/structured_params.rb
StructuredParams.register_types
```

### 1. API パラメータバリデーション

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :score, :integer
  attribute :tags, :array, value_type: :string           # プリミティブ配列
  attribute :address, :object, value_class: AddressParams # ネストオブジェクト

  # 型変換前の生文字列をバリデーション
  validates_raw :score, format: { with: /\A\d+\z/, message: 'must be numeric string' }
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
  validates :score, numericality: { greater_than_or_equal_to: 0 }
end

# API コントローラーで使用
def create
  user_params = UserParams.new(params)

  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors }, status: :unprocessable_entity
  end
end
```

#### プリミティブ配列

`value_type` を使うとプリミティブ型の配列を扱えます。Strong Parameters では配列フォーマット（`tags: []`）で許可されます。

```ruby
class UserParams < StructuredParams::Params
  attribute :tags, :array, value_type: :string
end

# Strong Parameters と同等:
# params.permit(tags: [])
```

### 2. フォームオブジェクト

```ruby
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :terms_accepted, :boolean

  validates :name, :email, presence: true
  validates :terms_accepted, acceptance: true
end

# コントローラーで使用
# ActionController::Parameters を Form クラスに渡すと、内部で
# params.require(:user_registration).permit(...) が自動的に呼ばれます。
# この挙動を使うには、クラス名を `Form` で終わらせてください。
def create
  form = UserRegistrationForm.new(params)

  if form.valid?
    User.create!(form.attributes)
    redirect_to root_path
  else
    render :new
  end
end
```

### 3. OpenAPI drift check(別 gem)

OpenAPI の schema と Params クラスの差分検出は、別 gem の
[`structured_params-openapi`](structured_params-openapi/README_ja.md) として提供しています。

```ruby
# Gemfile
gem 'structured_params-openapi'
```

```sh
bundle exec rake structured_params:openapi:drift_check
```

## ドキュメント

- **[インストールとセットアップ](structured_params/docs/installation.md)** - StructuredParams の始め方
- **[基本的な使い方](structured_params/docs/basic-usage.md)** - パラメータクラス、ネストオブジェクト、配列
- **[バリデーション](structured_params/docs/validation.md)** - ネスト構造での ActiveModel バリデーション
- **[OpenAPI Drift Check](structured_params-openapi/docs/drift-check_ja.md)** - OpenAPI schema と Params class の乖離検出(`structured_params-openapi` gem)
- **[Strong Parameters](structured_params/docs/strong-parameters.md)** - permit リストの自動生成
- **[エラーハンドリング](structured_params/docs/error-handling.md)** - フラット形式と構造化形式のエラー
- **[シリアライゼーション](structured_params/docs/serialization.md)** - パラメータのハッシュと JSON 変換
- **[フォームオブジェクト](structured_params/docs/form-objects.md)** - Rails ビューとのフォームオブジェクトパターン

## コントリビューション

バグレポートやプルリクエストは GitHub の https://github.com/Syati/structured_params で歓迎しています。

## ライセンス

この gem は [MIT License](https://opensource.org/licenses/MIT) のもとで公開されています。
