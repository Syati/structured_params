# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::I18n do
  # Reset global configuration after each example to avoid test pollution
  after { StructuredParams.reset_configuration! }

  describe '.human_attribute_name' do
    describe 'flat attributes (without dot notation)' do
      it 'delegates to the default ActiveModel implementation' do
        expect(UserParameter.human_attribute_name(:name)).to eq('Name')
        expect(UserParameter.human_attribute_name(:email)).to eq('Email')
        expect(UserParameter.human_attribute_name(:age)).to eq('Age')
      end

      it 'returns the same result for String and Symbol' do
        expect(UserParameter.human_attribute_name('name')).to eq('Name')
        expect(UserParameter.human_attribute_name(:name)).to eq('Name')
      end

      it 'accepts an options hash without raising errors' do
        expect { UserParameter.human_attribute_name(:name, {}) }.not_to raise_error
      end
    end

    describe 'nested object attributes (parent.child)' do
      it 'concatenates parent and child human_attribute_name' do
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
        expect(UserParameter.human_attribute_name(:'address.prefecture')).to eq('Address Prefecture')
        expect(UserParameter.human_attribute_name(:'address.city')).to eq('Address City')
      end

      it 'returns the same result for String input' do
        expect(UserParameter.human_attribute_name('address.postal_code')).to eq('Address Postal code')
      end
    end

    describe 'nested array attributes (parent.index.child)' do
      it 'joins parent, index, and child labels with spaces by default' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.0.level')).to eq('Hobbies 0 Level')
        expect(UserParameter.human_attribute_name(:'hobbies.0.years_experience')).to eq('Hobbies 0 Years experience')
      end

      it 'reflects different indices as-is' do
        expect(UserParameter.human_attribute_name(:'hobbies.1.name')).to eq('Hobbies 1 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.5.level')).to eq('Hobbies 5 Level')
        expect(UserParameter.human_attribute_name(:'hobbies.10.name')).to eq('Hobbies 10 Name')
      end
    end

    describe 'fallback for attributes missing in child classes' do
      it 'returns a humanized attribute name' do
        expect(UserParameter.human_attribute_name(:'address.unknown_field')).to eq('Address Unknown field')
        expect(UserParameter.human_attribute_name(:'hobbies.0.unknown_field')).to eq('Hobbies 0 Unknown field')
      end
    end

    describe 'when dotted attributes are not structured attributes' do
      it 'delegates to super (ActiveModel default)' do
        # :name は structured_attribute ではないので super に委譲
        # ActiveModel はドット区切りの末尾セグメントを humanize して返す
        expect(UserParameter.human_attribute_name(:'name.something')).to eq('Something')
      end
    end
  end

  describe 'custom i18n format keys' do
    describe 'array format key (activemodel.errors.nested_attribute.array)' do
      context 'when the array format key is configured' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          {
            activemodel: {
              errors: {
                nested_attribute: {
                  array: '%<parent>s %<index>s 番目の%<child>s'
                }
              }
            }
          }
        end

        it 'builds labels using the configured format' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
          expect(UserParameter.human_attribute_name(:'hobbies.3.level')).to eq('趣味 3 番目のレベル')
          expect(UserParameter.human_attribute_name(:'hobbies.10.years_experience')).to eq('趣味 10 番目の経験年数')
        end

        it 'uses default space-separated format when object format key is missing' do
          # activemodel.errors.nested_attribute.object is not configured
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所 郵便番号')
        end
      end

      context 'when the array format key is not configured' do
        it 'uses the default space-separated format' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        end
      end
    end

    describe 'object format key (activemodel.errors.nested_attribute.object)' do
      context 'when the object format key is configured' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          {
            activemodel: {
              errors: {
                nested_attribute: {
                  object: '%<parent>sの%<child>s'
                }
              }
            }
          }
        end

        it 'builds labels using the configured format' do
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所の郵便番号')
          expect(UserParameter.human_attribute_name(:'address.prefecture')).to eq('住所の都道府県')
        end

        it 'uses default space-separated format when array format key is missing' do
          # activemodel.errors.nested_attribute.array is not configured
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 名前')
        end
      end

      context 'when the object format key is not configured' do
        it 'uses the default space-separated format' do
          expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('Address Postal code')
        end
      end
    end

    describe 'using value_class i18n translations' do
      context 'when parent and value_class define the same attribute name differently' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          {
            activemodel: {
              attributes: {
                user: { name: 'ユーザー名' },
                hobby: { name: 'ホビー名' }
              },
              errors: {
                nested_attribute: {
                  array: '%<parent>s %<index>s 番目の%<child>s'
                }
              }
            }
          }
        end

        it 'uses value_class (HobbyParameter) translation for hobbies.0.name' do
          result = UserParameter.human_attribute_name(:'hobbies.0.name')
          expect(result).to eq('趣味 0 番目のホビー名')
        end

        it 'does not use the parent class (UserParameter) translation for the same attribute' do
          result = UserParameter.human_attribute_name(:'hobbies.0.name')
          expect(result).not_to include('ユーザー名')
        end
      end
    end

    describe 'when both array and object keys are configured' do
      include_context 'with ja locale'

      let(:ja_overrides) do
        {
          activemodel: {
            errors: {
              nested_attribute: {
                array: '%<parent>s %<index>s 番目の%<child>s',
                object: '%<parent>sの%<child>s'
              }
            }
          }
        }
      end

      it 'uses array format for array attributes' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
      end

      it 'uses object format for object attributes' do
        expect(UserParameter.human_attribute_name(:'address.postal_code')).to eq('住所の郵便番号')
      end
    end
  end

  describe 'explicit locale: option threading' do
    include_context 'with ja locale'

    let(:ja_overrides) do
      {
        activemodel: {
          errors: {
            nested_attribute: {
              array: '%<parent>s %<index>s 番目の%<child>s',
              object: '%<parent>sの%<child>s'
            }
          }
        }
      }
    end

    context 'when locale: :ja is passed while the current locale is :en' do
      it 'resolves array attribute labels in ja' do
        I18n.with_locale(:en) do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name', locale: :ja)).to eq('趣味 0 番目の名前')
        end
      end

      it 'resolves object attribute labels in ja' do
        I18n.with_locale(:en) do
          expect(UserParameter.human_attribute_name(:'address.postal_code', locale: :ja)).to eq('住所の郵便番号')
        end
      end
    end

    context 'when locale: :en is passed while the current locale is :ja' do
      it 'resolves array attribute labels in en' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name', locale: :en)).to eq('Hobbies 0 Name')
      end

      it 'resolves object attribute labels in en' do
        expect(UserParameter.human_attribute_name(:'address.postal_code', locale: :en)).to eq('Address Postal code')
      end
    end
  end

  describe 'StructuredParams.configuration.array_index_base' do
    describe 'default (array_index_base: 0, 0-based)' do
      it 'displays raw 0-based indices in the default en format' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 0 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.2.name')).to eq('Hobbies 2 Name')
      end

      context 'with ja locale and array format key' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          { activemodel: { errors: { nested_attribute: { array: '%<parent>s %<index>s 番目の%<child>s' } } } }
        end

        it 'displays 0-based indices in the ja format' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 0 番目の名前')
          expect(UserParameter.human_attribute_name(:'hobbies.2.name')).to eq('趣味 2 番目の名前')
        end
      end
    end

    describe 'array_index_base: 1 (1-based, human-friendly)' do
      before { StructuredParams.configure { |c| c.array_index_base = 1 } }

      it 'adds 1 to the raw index in the default en format' do
        # path .0. → display 1, path .2. → display 3
        expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('Hobbies 1 Name')
        expect(UserParameter.human_attribute_name(:'hobbies.2.name')).to eq('Hobbies 3 Name')
      end

      it 'applies to API param error messages as well as Form Object full_messages (same code path)' do
        expect(UserParameter.human_attribute_name(:'hobbies.0.level')).to eq('Hobbies 1 Level')
      end

      context 'with ja locale and array format key' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          { activemodel: { errors: { nested_attribute: { array: '%<parent>s %<index>s 番目の%<child>s' } } } }
        end

        it 'displays 1-based indices in the ja format' do
          expect(UserParameter.human_attribute_name(:'hobbies.0.name')).to eq('趣味 1 番目の名前')
          expect(UserParameter.human_attribute_name(:'hobbies.2.name')).to eq('趣味 3 番目の名前')
        end
      end

      context 'when locale: :ja is passed explicitly' do
        include_context 'with ja locale'

        let(:ja_overrides) do
          { activemodel: { errors: { nested_attribute: { array: '%<parent>s %<index>s 番目の%<child>s' } } } }
        end

        it 'threads both locale option and 1-based index correctly' do
          I18n.with_locale(:en) do
            result = UserParameter.human_attribute_name(:'hobbies.0.name', locale: :ja)
            expect(result).to eq('趣味 1 番目の名前')
          end
        end
      end
    end

    describe 'validation of array_index_base=' do
      it 'raises ArgumentError for values other than 0 or 1' do
        expect { StructuredParams.configure { |c| c.array_index_base = 2 } }
          .to raise_error(ArgumentError, /array_index_base must be 0 or 1/)
      end

      it 'raises ArgumentError for negative values' do
        expect { StructuredParams.configure { |c| c.array_index_base = -1 } }
          .to raise_error(ArgumentError, /array_index_base must be 0 or 1/)
      end

      it 'raises ArgumentError for non-integer values (string)' do
        expect { StructuredParams.configure { |c| c.array_index_base = '1' } }
          .to raise_error(ArgumentError, /array_index_base must be 0 or 1/)
      end

      it 'raises ArgumentError for non-integer values (boolean)' do
        expect { StructuredParams.configure { |c| c.array_index_base = true } }
          .to raise_error(ArgumentError, /array_index_base must be 0 or 1/)
      end

      it 'accepts 0' do
        expect { StructuredParams.configure { |c| c.array_index_base = 0 } }.not_to raise_error
        expect(StructuredParams.configuration.array_index_base).to eq(0)
      end

      it 'accepts 1' do
        expect { StructuredParams.configure { |c| c.array_index_base = 1 } }.not_to raise_error
        expect(StructuredParams.configuration.array_index_base).to eq(1)
      end
    end
  end
end
