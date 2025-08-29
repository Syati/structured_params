# StructuredParams

StructuredParams は、Rails アプリケーションでタイプセーフなパラメータバリデーションとキャストを提供する Ruby gem です。ActiveModel の型システムを拡張して、ネストしたオブジェクトや配列を自動的な Strong Parameters 統合と共に処理します。

[English](README.md) | 日本語

## 特徴

- **ActiveModel::Type を使用したタイプセーフなパラメータバリデーション**
- **自動キャストによるネストオブジェクトサポート**
- **プリミティブ型とネストオブジェクトの両方に対応した配列処理**
- **自動 permit リスト生成による Strong Parameters 統合**
- **バリデーションとシリアライゼーションを含む ActiveModel 互換性**
- **より良い開発体験のための RBS 型定義**

## インストール

Gemfile に以下の行を追加してください：

```ruby
gem 'structured_params'
```

そして実行：

```bash
$ bundle install
```

または手動でインストール：

```bash
$ gem install structured_params
```

## セットアップ

Rails アプリケーションでカスタム型を登録します：

```ruby
# config/initializers/structured_params.rb
StructuredParams.register_types
```

これにより `:object` と `:array` 型が ActiveModel::Type に登録されます。

## 使用方法

### 基本的なパラメータクラス

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :email, :string
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end

# コントローラーでの使用
def create
  user_params = UserParams.new(params[:user])
  if user_params.valid?
    User.create!(user_params.attributes)
  else
    render json: { errors: user_params.errors }
  end
end
```

### ネストしたオブジェクト

```ruby
class AddressParams < StructuredParams::Params
  attribute :street, :string
  attribute :city, :string
  attribute :postal_code, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :address, :object, value_class: AddressParams
end

# 使用例
params = {
  name: "山田太郎",
  address: {
    street: "新宿区新宿1-1-1",
    city: "東京都",
    postal_code: "160-0022"
  }
}

user_params = UserParams.new(params)
user_params.address # => AddressParams インスタンス
user_params.address.city # => "東京都"
```

### 配列

#### プリミティブ型の配列

```ruby
class UserParams < StructuredParams::Params
  attribute :tags, :array, value_type: :string
  attribute :scores, :array, value_type: :integer
end

# 使用例
params = {
  tags: ["ruby", "rails", "programming"],
  scores: [85, 92, 78]
}

user_params = UserParams.new(params)
user_params.tags # => ["ruby", "rails", "programming"]
user_params.scores # => [85, 92, 78]
```

#### ネストオブジェクトの配列

```ruby
class HobbyParams < StructuredParams::Params
  attribute :name, :string
  attribute :level, :string
end

class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :hobbies, :array, value_class: HobbyParams
end

# 使用例
params = {
  name: "佐藤花子",
  hobbies: [
    { name: "写真", level: "初心者" },
    { name: "料理", level: "中級者" }
  ]
}

user_params = UserParams.new(params)
user_params.hobbies # => [HobbyParams, HobbyParams]
user_params.hobbies.first.name # => "写真"
```

### Strong Parameters 統合

StructuredParams は Strong Parameters 用の permit リストを自動生成します：

```ruby
class UsersController < ApplicationController
  def create
    permitted_params = params.require(:user).permit(*UserParams.permit_attribute_names)
    user_params = UserParams.new(permitted_params)
    
    if user_params.valid?
      User.create!(user_params.attributes)
    else
      render json: { errors: user_params.errors }
    end
  end
end

# UserParams.permit_attribute_names は以下を返します：
# [:name, :age, :email, { address: [:street, :city, :postal_code] }, { hobbies: [:name, :level] }]
```

### バリデーション

StructuredParams は ActiveModel を継承しているため、すべての ActiveModel バリデーションを使用できます：

```ruby
class UserParams < StructuredParams::Params
  attribute :name, :string
  attribute :age, :integer
  attribute :email, :string
  attribute :address, :object, value_class: AddressParams
  
  validates :name, presence: true, length: { minimum: 2 }
  validates :age, presence: true, numericality: { greater_than: 0 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :address, presence: true
  
  validate :custom_validation
  
  private
  
  def custom_validation
    errors.add(:age, "成人である必要があります") if age && age < 18
  end
end
```

### シリアライゼーション

```ruby
user_params = UserParams.new(params)
user_params.attributes # => すべての属性を含むハッシュ
user_params.to_json    # => JSON 文字列
```

## 高度な使用方法

### カスタム型登録

潜在的な命名衝突を避けたい場合、カスタム名で型を登録できます：

```ruby
# カスタム名で登録
StructuredParams.register_types_as(
  object_name: :structured_object,
  array_name: :structured_array
)

# パラメータクラスで使用
class UserParams < StructuredParams::Params
  attribute :address, :structured_object, value_class: AddressParams
  attribute :hobbies, :structured_array, value_class: HobbyParams
end
```

### 型の内省

```ruby
user_params = UserParams.new(params)

# 属性の型を確認
UserParams.attribute_types[:name].type        # => :string
UserParams.attribute_types[:address].type     # => :object
UserParams.attribute_types[:hobbies].type     # => :array

# ネストした value_class にアクセス
UserParams.attribute_types[:address].value_class  # => AddressParams
UserParams.attribute_types[:hobbies].value_class  # => HobbyParams
```

## 開発

リポジトリをチェックアウト後、`bin/setup` を実行して依存関係をインストールしてください。その後、`rake spec` でテストを実行できます。また、`bin/console` で対話的なプロンプトを使用して実験することもできます。

ローカルマシンにこの gem をインストールするには、`bundle exec rake install` を実行してください。新しいバージョンをリリースするには、`version.rb` でバージョン番号を更新し、`bundle exec rake release` を実行してください。これにより、バージョンの git タグが作成され、git コミットとタグがプッシュされ、`.gem` ファイルが [rubygems.org](https://rubygems.org) にプッシュされます。

## コントリビューション

バグレポートやプルリクエストは GitHub の https://github.com/Syati/structured_params で歓迎しています。

## ライセンス

この gem は [MIT License](https://opensource.org/licenses/MIT) の条件の下でオープンソースとして利用可能です。
