# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::Errors do
  let(:errors) { build(:user_parameter).errors }

  before { errors.clear }

  describe '#to_hash' do
    subject(:errors_to_hash) { errors.to_hash(option_full_messages, structured: option_structured) }

    let(:option_full_messages) { false }
    let(:option_structured) { false }

    context 'with default behavior (structured: false)' do
      before do
        errors.add('name', "can't be blank")
        errors.add('address.postal_code', "can't be blank")
        errors.add('hobbies.0.name', 'is required')
      end

      it 'returns flat structure like standard ActiveModel::Errors' do
        expect(errors_to_hash).to eq({
                                       name: ["can't be blank"],
                                       'address.postal_code': ["can't be blank"],
                                       'hobbies.0.name': ['is required']
                                     })
      end

      context 'with full_messages = true' do
        let(:option_full_messages) { true }

        it 'returns flat structure with full messages' do
          expect(errors_to_hash[:name]).to contain_exactly("Name can't be blank")
          expect(errors_to_hash[:'address.postal_code']).to contain_exactly("Address postal code can't be blank")
          expect(errors_to_hash[:'hobbies.0.name']).to contain_exactly('Hobbies 0 name is required')
        end
      end
    end

    context 'with structured option (structured: true)' do
      let(:option_structured) { true }

      context 'with some nested errors' do
        before do
          # Add some nested errors
          errors.add('name', "can't be blank")
          errors.add('address.postal_code', "can't be blank")
          errors.add('address.prefecture', 'is invalid')
          errors.add('hobbies.0.name', "can't be blank")
          errors.add('hobbies.0.level', 'is not included in the list')
          errors.add('hobbies.1.name', 'is too short')
        end

        context 'with full_messages = false (default)' do
          it 'returns nested structure for dot-notation attributes' do
            expect(errors_to_hash).to eq({ 'name' => ["can't be blank"],
                                           'address' => {
                                             'postal_code' => ["can't be blank"],
                                             'prefecture' => ['is invalid']
                                           },
                                           'hobbies' => {
                                             '0' => {
                                               'name' => ["can't be blank"],
                                               'level' => ['is not included in the list']
                                             },
                                             '1' => {
                                               'name' => ['is too short']
                                             }
                                           } })
          end
        end

        context 'with full_messages = true' do
          let(:option_full_messages) { true }

          it 'returns nested structure with full error messages' do
            # Check that full messages are used (they include attribute names)
            expect(errors_to_hash['name']).to contain_exactly("Name can't be blank")
            expect(errors_to_hash['address']).to include('postal_code' => ["Address postal code can't be blank"])
            expect(errors_to_hash['hobbies']).to include(
              '0' => hash_including('name' => ["Hobbies 0 name can't be blank"])
            )
          end
        end
      end

      context 'with only flat attributes' do
        before do
          errors.add('name', "can't be blank")
          errors.add('email', 'is invalid')
        end

        it 'returns flat structure for non-nested attributes' do
          expect(errors.to_hash(false, structured: true)).to eq({
                                                                  'name' => ["can't be blank"],
                                                                  'email' => ['is invalid']
                                                                })
        end
      end

      context 'with deeply nested attributes' do
        before do
          errors.add('items.0.subitems.1.name', "can't be blank")
          errors.add('items.1.subitems.0.description', 'is too long')
        end

        # rubocop:disable RSpec/ExampleLength
        it 'creates deep nested structure' do
          expect(errors.to_hash(false, structured: true)).to eq({
                                                                  'items' => {
                                                                    '0' => {
                                                                      'subitems' => {
                                                                        '1' => {
                                                                          'name' => ["can't be blank"]
                                                                        }
                                                                      }
                                                                    },
                                                                    '1' => {
                                                                      'subitems' => {
                                                                        '0' => {
                                                                          'description' => ['is too long']
                                                                        }
                                                                      }
                                                                    }
                                                                  }
                                                                })
        end
        # rubocop:enable RSpec/ExampleLength
      end

      context 'with mixed flat and nested attributes' do
        before do
          errors.add('name', "can't be blank")
          errors.add('address.postal_code', "can't be blank")
          errors.add('email', 'is invalid')
          errors.add('hobbies.0.name', 'is required')
        end

        it 'handles both flat and nested attributes correctly' do
          expect(errors.to_hash(false, structured: true)).to eq({
                                                                  'name' => ["can't be blank"],
                                                                  'email' => ['is invalid'],
                                                                  'address' => {
                                                                    'postal_code' => ["can't be blank"]
                                                                  },
                                                                  'hobbies' => {
                                                                    '0' => {
                                                                      'name' => ['is required']
                                                                    }
                                                                  }
                                                                })
        end
      end

      context 'with multiple errors on same attribute' do
        before do
          errors.add('address.postal_code', "can't be blank")
          errors.add('address.postal_code', 'is invalid format')
          errors.add('hobbies.0.name', "can't be blank")
          errors.add('hobbies.0.name', 'is too short')
        end

        it 'groups multiple errors for the same nested attribute' do
          expect(errors.to_hash(false, structured: true)).to eq({
                                                                  'address' => {
                                                                    'postal_code' => ["can't be blank",
                                                                                      'is invalid format']
                                                                  },
                                                                  'hobbies' => {
                                                                    '0' => {
                                                                      'name' => ["can't be blank", 'is too short']
                                                                    }
                                                                  }
                                                                })
        end
      end

      context 'with empty errors' do
        it 'returns empty hash' do
          expect(errors.to_hash(false, structured: true)).to eq({})
        end
      end
    end
  end

  describe '#build_nested_hash' do
    let(:target_hash) { {} }

    context 'with simple nested key' do
      it 'creates nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'address.postal_code' => ['error'] })

        expect(target_hash).to eq({
                                    'address' => {
                                      'postal_code' => ['error']
                                    }
                                  })
      end
    end

    context 'with array index in key' do
      it 'creates structure with array index as string key' do
        errors.send(:build_nested_hash, target_hash, { 'hobbies.0.name' => ['error'] })

        expect(target_hash).to eq({
                                    'hobbies' => {
                                      '0' => {
                                        'name' => ['error']
                                      }
                                    }
                                  })
      end
    end

    context 'with deeply nested key' do
      it 'creates deep nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'a.b.c.d.e' => ['deep error'] })

        expect(target_hash).to eq({
                                    'a' => {
                                      'b' => {
                                        'c' => {
                                          'd' => {
                                            'e' => ['deep error']
                                          }
                                        }
                                      }
                                    }
                                  })
      end
    end

    context 'with existing structure' do
      before do
        target_hash['address'] = { 'city' => ['existing error'] }
      end

      it 'preserves existing nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'address.postal_code' => ['new error'] })

        expect(target_hash).to eq({
                                    'address' => {
                                      'city' => ['existing error'],
                                      'postal_code' => ['new error']
                                    }
                                  })
      end
    end

    context 'with custom separator' do
      it 'uses custom separator for splitting keys' do
        errors.send(:build_nested_hash, target_hash, { 'address/postal_code' => ['error'] }, '/')

        expect(target_hash).to eq({
                                    'address' => {
                                      'postal_code' => ['error']
                                    }
                                  })
      end
    end

    context 'with flat key (no separator)' do
      it 'adds key directly without nesting' do
        errors.send(:build_nested_hash, target_hash, { 'name' => ['error'] })

        expect(target_hash).to eq({
                                    'name' => ['error']
                                  })
      end
    end
  end

  describe '#messages_with' do
    before do
      errors.add('name', "can't be blank")
      errors.add('address.postal_code', "can't be blank")
      errors.add('hobbies.0.name', 'is required')
      errors.add('hobbies.1.level', 'is invalid')
    end

    context 'with JSON Pointer transformation' do
      it 'converts attribute keys to JSON Pointer format' do
        result = errors.messages_with { |attr| "/#{attr.gsub('.', '/')}" }

        expect(result).to eq({
                               '/name' => ["can't be blank"],
                               '/address/postal_code' => ["can't be blank"],
                               '/hobbies/0/name' => ['is required'],
                               '/hobbies/1/level' => ['is invalid']
                             })
      end
    end

    context 'with uppercase transformation' do
      it 'converts attribute keys to uppercase' do
        result = errors.messages_with(&:upcase)

        expect(result).to eq({
                               'NAME' => ["can't be blank"],
                               'ADDRESS.POSTAL_CODE' => ["can't be blank"],
                               'HOBBIES.0.NAME' => ['is required'],
                               'HOBBIES.1.LEVEL' => ['is invalid']
                             })
      end
    end

    context 'with custom prefix transformation' do
      it 'adds custom prefix to attribute keys' do
        result = errors.messages_with { |attr| "error_#{attr}" }

        expect(result).to eq({
                               'error_name' => ["can't be blank"],
                               'error_address.postal_code' => ["can't be blank"],
                               'error_hobbies.0.name' => ['is required'],
                               'error_hobbies.1.level' => ['is invalid']
                             })
      end
    end

    context 'with full_messages = true' do
      it 'returns full error messages with transformed keys' do
        result = errors.messages_with(true) { |attr| "/#{attr.gsub('.', '/')}" }

        expect(result).to be_a(Hash)
        expect(result.keys).to include('/name', '/address/postal_code', '/hobbies/0/name')

        # Check that full messages are used (they include attribute names)
        expect(result['/name']).to contain_exactly("Name can't be blank")
        expect(result['/address/postal_code']).to contain_exactly("Address postal code can't be blank")
        expect(result['/hobbies/0/name']).to contain_exactly('Hobbies 0 name is required')
      end
    end

    context 'with empty errors' do
      before { errors.clear }

      it 'returns empty hash' do
        result = errors.messages_with(&:upcase)
        expect(result).to eq({})
      end
    end
  end
end
