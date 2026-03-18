# StructuredParams

[English](README.md) | 日本語

**Rails で型安全な API パラメータバリデーションとフォームオブジェクトを実現する gem**

StructuredParams は、以下の課題を解決します：

- **API エンドポイント**: リクエストパラメータの型チェック・バリデーション・自動キャスト
- **フォームオブジェクト**: 複雑なフォーム入力の検証とモデルへの変換

ActiveModel をベースに、ネストしたオブジェクトや配列も簡単に扱えます。

## 主な特徴

- ✅ **API パラメータバリデーション** - 型安全なリクエスト検証
- ✅ **フォームオブジェクト** - 複雑なフォームロジックのカプセル化
- ✅ **ネスト構造対応** - オブジェクトや配列を自動キャスト
- ✅ **Strong Parameters 統合** - permit リストを自動生成
- ✅ **ActiveModel 互換** - バリデーション、シリアライゼーションなど標準機能をサポート
- ✅ **RBS 型定義** - 型安全な開発体験

## クイックスタート

```ruby
# インストール
gem 'structured_params'

# 初期化
StructuredParams.register_types
```

### 1. API パラメータバリデーション

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end

# API コントローラーで使用
def create
  permitted = UserParams.permit(params, require: false)
  user_params = UserParams.new(permitted)
  
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors }, status: :unprocessable_entity
  end
end
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
def create
  form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
  
  if form.valid?
    User.create!(form.attributes)
    redirect_to root_path
  else
    render :new
  end
end
```

## ドキュメント

- **[インストールとセットアップ](docs/installation.md)** - StructuredParams の始め方
- **[基本的な使用方法](docs/basic-usage.md)** - パラメータクラス、ネストオブジェクト、配列
- **[バリデーション](docs/validation.md)** - ネスト構造でのActiveModelバリデーション使用
- **[Strong Parameters](docs/strong-parameters.md)** - 自動permit リスト生成
- **[エラーハンドリング](docs/error-handling.md)** - フラットと構造化エラーフォーマット
- **[シリアライゼーション](docs/serialization.md)** - パラメータのハッシュとJSON変換
- **[Gem比較](docs/comparison.md)** - typed_params、dry-validation、reformとの比較


## コントリビューション

バグレポートやプルリクエストは GitHub の https://github.com/Syati/structured_params で歓迎しています。

## ライセンス

この gem は [MIT License](https://opensource.org/licenses/MIT) の条件の下でオープンソースとして利用可能です。
