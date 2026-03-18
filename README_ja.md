# StructuredParams

StructuredParams は、Rails アプリケーションでタイプセーフなパラメータバリデーションとキャストを提供する Ruby gem です。ActiveModel の型システムを拡張して、ネストしたオブジェクトや配列を自動的な Strong Parameters 統合と共に処理します。

[English](README.md) | 日本語

## 特徴

- **ActiveModel::Type を使用したタイプセーフなパラメータバリデーション**
- **自動キャストによるネストオブジェクトサポート**
- **プリミティブ型とネストオブジェクトの両方に対応した配列処理**
- **自動 permit リスト生成による Strong Parameters 統合**
- **バリデーションとシリアライゼーションを含む ActiveModel 互換性**
- **Rails フォームヘルパーと統合された Form Object パターンのサポート**
- **フラットと構造化フォーマットによる拡張エラーハンドリング**
- **より良い開発体験のための RBS 型定義**

## クイックスタート

```ruby
# 1. gem をインストール
gem 'structured_params'

# 2. イニシャライザで型を登録
StructuredParams.register_types

# 3. パラメータクラスを定義
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :address, :object, value_class: AddressParams
  attribute :hobbies, :array, value_class: HobbyParams
  
  validates :name, presence: true
  validates :age, numericality: { greater_than: 0 }
end

# 4. コントローラーで使用（API向け）
def create
  user_params = UserParams.new(params)
  
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors.to_hash(false, structured: true) }
  end
end

# 5. Form Object として使用（View統合）

# Form Object クラスを定義
class UserRegistrationForm < StructuredParams::Params
  attribute :name, :string
  attribute :email, :string
  attribute :password, :string
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# コントローラーで使用
def create
  @form = UserRegistrationForm.new(UserRegistrationForm.permit(params))
  
  if @form.valid?
    User.create!(@form.attributes)
    redirect_to user_path
  else
    render :new
  end
end

# View で使用
<%= form_with model: @form, url: users_path do |f| %>
  <%= f.text_field :name %>
  <%= f.email_field :email %>
  <%= f.password_field :password %>
<% end %>
```

## ドキュメント

- **[インストールとセットアップ](docs/installation.md)** - StructuredParams の始め方
- **[基本的な使用方法](docs/basic-usage.md)** - パラメータクラス、ネストオブジェクト、配列
- **[バリデーション](docs/validation.md)** - ネスト構造でのActiveModelバリデーション使用
- **[Strong Parameters](docs/strong-parameters.md)** - 自動permit リスト生成
- **[Form Object](docs/form-objects.md)** - Rails フォームヘルパーとの Form Object としての使用
- **[エラーハンドリング](docs/error-handling.md)** - フラットと構造化エラーフォーマット
- **[シリアライゼーション](docs/serialization.md)** - パラメータのハッシュとJSON変換


## コントリビューション

バグレポートやプルリクエストは GitHub の https://github.com/Syati/structured_params で歓迎しています。

## ライセンス

この gem は [MIT License](https://opensource.org/licenses/MIT) の条件の下でオープンソースとして利用可能です。
