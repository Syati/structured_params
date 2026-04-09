# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::I18n do
  describe '.human_attribute_name' do
    describe 'フラット属性（ドット記法なし）' do
      it 'ActiveModel のデフォルト実装に委譲する' do
        expect(UserParameter.human_attribute_name(:name)).to eq('Name')
        expect(UserParameter.human_attribute_name(:email)).to eq('Email')
        expect(UserParameter.human_attribute_name(:age)).to eq('Age')
      end

      it 'String でも Symbol でも同じ結果を返す' do
        expect(UserParameter.human_attribute_name('name')).to eq('Name')
        expect(UserParameter.human_attribute_name(:name)).to eq('Name')
      end

      it 'options ハッシュを受け取ってもエラーにならない' do
        expect { UserParameter.human_attribute_name(:name, {}) }.not_to raise_error
      end
    end

    describe 'ネスト object 属性（parent.child）' do
      it '親クラスと子クラスの human_attribute_name を連結する' do
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
        expect(UserParameter.human_attribute_name(:'address.prefecture')).to eq('Address Prefecture')
        expect(UserParameter.human_attribute_name(:'address.city')).to eq('Address City')
      end

      it 'String 形式でも同じ結果を返す' do
        expect(UserParameter.human_attribute_name('address.postal_code')).to eq('Address Postal code')
      end
    end

    describe 'ネスト array 属性（parent.index.child）' do
      it '親・インデックス・子のラベルをスペース区切りで連結する（デフォルト）' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.0.level')).to eq('Hobbies 0 Level')
        expect(UserParameter.human_attribute_name(:'hobbies.0.years_experience')).to eq('Hobbies 0 Years experience')
      end

      it '異なるインデックスをそのまま反映する' do
        expect(UserParameter.human_attribute_name(:'hobbies.1.name')).to eq('Hobbies 1 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.5.level')).to eq('Hobbies 5 Level')
        expect(UserParameter.human_attribute_name(:'hobbies.10.name')).to eq('Hobbies 10 Name')
      end
    end

    describe '子クラスに存在しない属性（フォールバック）' do
      it 'humanize した属性名を返す' do
        expect(UserParameter.human_attribute_name(:'address.unknown_field')).to eq('Address Unknown field')
        expect(UserParameter.human_attribute_name(:'hobbies.0.unknown_field')).to eq('Hobbies 0 Unknown field')
      end
    end

    describe 'structured_attribute でない属性にドットが含まれる場合' do
      it 'super（ActiveModel デフォルト）に委譲する' do
        # :name は structured_attribute ではないので super に委譲
        # ActiveModel はドット区切りの末尾セグメントを humanize して返す
        expect(UserParameter.human_attribute_name(:'name.something')).to eq('Something')
      end
    end
  end

  describe 'i18n フォーマットキーのカスタマイズ' do
    describe 'array フォーマットキー（structured_params.errors.nested_attribute.array）' do
      context 'when the array format key is configured' do
        include_context 'with ja locale'

        let(:ja_locale_files) { %w[i18n_array_format] }

        it '設定したフォーマットでラベルを生成する' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
          expect(UserParameter.human_attribute_name(:'hobbies.3.level')).to eq('趣味 3 番目のレベル')
          expect(UserParameter.human_attribute_name(:'hobbies.10.years_experience')).to eq('趣味 10 番目の経験年数')
        end

        it 'object フォーマットキーが未設定の場合はデフォルト（スペース区切り）を使う' do
          # structured_params.errors.nested_attribute.object は未設定
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
        end
      end

      context 'when the array format key is not configured' do
        it 'デフォルトのスペース区切りフォーマットを使う' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        end
      end
    end

    describe 'object フォーマットキー（structured_params.errors.nested_attribute.object）' do
      context 'when the object format key is configured' do
        include_context 'with ja locale'

        let(:ja_locale_files) { %w[i18n_object_format] }

        it '設定したフォーマットでラベルを生成する' do
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所の郵便番号')
          expect(UserParameter.human_attribute_name(:'address.prefecture')).to eq('住所の都道府県')
        end

        it 'array フォーマットキーが未設定の場合はデフォルト（スペース区切り）を使う' do
          # structured_params.errors.nested_attribute.array は未設定
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        end
      end

      context 'when the object format key is not configured' do
        it 'デフォルトのスペース区切りフォーマットを使う' do
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
        end
      end
    end

    describe 'value_class の i18n を使うこと' do
      context 'when parent and value_class define the same attribute name differently' do
        include_context 'with ja locale'

        let(:ja_locale_files) { %w[i18n_value_class] }

        it 'hobbies.0.name には value_class (HobbyParameter) の訳語を使う' do
          result = UserParameter.human_attribute_name(:'hobbies.0.name')
          expect(result).to eq('趣味 0 番目のホビー名')
        end

        it '親クラス (UserParameter) の同名属性訳語は使わない' do
          result = UserParameter.human_attribute_name(:'hobbies.0.name')
          expect(result).not_to include('ユーザー名')
        end
      end
    end

    describe 'array / object 両キーが設定されている場合' do
      include_context 'with ja locale'

      let(:ja_locale_files) { %w[i18n_array_and_object_formats] }

      it 'array 属性には array フォーマットを使う' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
      end

      it 'object 属性には object フォーマットを使う' do
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所の郵便番号')
      end
    end
  end
end
