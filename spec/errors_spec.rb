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
            expect(errors_to_hash).to eq({ name: ["can't be blank"],
                                           address: {
                                             postal_code: ["can't be blank"],
                                             prefecture: ['is invalid']
                                           },
                                           hobbies: {
                                             '0': {
                                               name: ["can't be blank"],
                                               level: ['is not included in the list']
                                             },
                                             '1': {
                                               name: ['is too short']
                                             }
                                           } })
          end
        end

        context 'with full_messages = true' do
          let(:option_full_messages) { true }

          it 'returns nested structure with full error messages' do
            # Check that full messages are used (they include attribute names)
            expect(errors_to_hash[:name]).to contain_exactly("Name can't be blank")
            expect(errors_to_hash[:address]).to include(postal_code: ["Address postal code can't be blank"])
            expect(errors_to_hash[:hobbies]).to include(
              '0': hash_including(name: ["Hobbies 0 name can't be blank"])
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
                                                                  name: ["can't be blank"],
                                                                  email: ['is invalid']
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
                                                                  items: {
                                                                    '0': {
                                                                      subitems: {
                                                                        '1': {
                                                                          name: ["can't be blank"]
                                                                        }
                                                                      }
                                                                    },
                                                                    '1': {
                                                                      subitems: {
                                                                        '0': {
                                                                          description: ['is too long']
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
                                                                  name: ["can't be blank"],
                                                                  email: ['is invalid'],
                                                                  address: {
                                                                    postal_code: ["can't be blank"]
                                                                  },
                                                                  hobbies: {
                                                                    '0': {
                                                                      name: ['is required']
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
                                                                  address: {
                                                                    postal_code: ["can't be blank",
                                                                                  'is invalid format']
                                                                  },
                                                                  hobbies: {
                                                                    '0': {
                                                                      name: ["can't be blank", 'is too short']
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

  describe '#as_json' do
    before do
      errors.add('name', "can't be blank")
      errors.add('address.postal_code', "can't be blank")
      allow(errors).to receive(:to_hash).and_call_original
    end

    context 'with default behavior (no structured option)' do
      it 'uses standard ActiveModel::Errors behavior when no options provided' do
        # ActiveModel::Errors.as_json calls to_hash(options && options[:full_messages])
        # When options is nil, it calls to_hash(nil), but our override calls super which handles this
        result = errors.as_json
        expect(result).to eq(errors.to_hash)
      end

      it 'delegates to standard behavior with full_messages option' do
        errors.as_json(full_messages: true)
        expect(errors).to have_received(:to_hash).with(true, structured: false)
      end
    end

    context 'with structured option' do
      it 'delegates to to_hash with structured: true' do
        errors.as_json(structured: true)
        expect(errors).to have_received(:to_hash).with(false, structured: true)
      end

      it 'delegates to to_hash with both full_messages and structured options' do
        errors.as_json(full_messages: true, structured: true)
        expect(errors).to have_received(:to_hash).with(true, structured: true)
      end
    end
  end

  describe '#messages' do
    before do
      errors.add('name', "can't be blank")
      errors.add('address.postal_code', "can't be blank")
      errors.add('hobbies.0.name', 'is required')
    end

    context 'with default behavior (structured: false)' do
      it 'uses standard ActiveModel::Errors behavior' do
        result = errors.messages

        expect(result).to eq({
                               name: ["can't be blank"],
                               'address.postal_code': ["can't be blank"],
                               'hobbies.0.name': ['is required']
                             })

        # Check that it has default value and is frozen
        expect(result.default).to eq([].freeze)
        expect(result).to be_frozen
      end
    end

    context 'with structured: true' do
      it 'returns structured format' do
        result = errors.messages(structured: true)

        expect(result).to eq({
                               name: ["can't be blank"],
                               address: { postal_code: ["can't be blank"] },
                               hobbies: { '0': { name: ['is required'] } }
                             })

        # Check that it has default value and is frozen
        expect(result.default).to eq([].freeze)
        expect(result).to be_frozen
      end
    end

    context 'with empty errors' do
      before { errors.clear }

      it 'returns empty frozen hash for default behavior' do
        result = errors.messages
        expect(result).to eq({})
        expect(result).to be_frozen
      end

      it 'returns empty frozen hash for structured behavior' do
        result = errors.messages(structured: true)
        expect(result).to eq({})
        expect(result).to be_frozen
      end
    end
  end

  describe '#build_nested_hash' do
    let(:target_hash) { {} }

    context 'with simple nested key' do
      it 'creates nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'address.postal_code' => ['error'] })

        expect(target_hash).to eq({
                                    address: {
                                      postal_code: ['error']
                                    }
                                  })
      end
    end

    context 'with array index in key' do
      it 'creates structure with array index as symbol key' do
        errors.send(:build_nested_hash, target_hash, { 'hobbies.0.name' => ['error'] })

        expect(target_hash).to eq({
                                    hobbies: {
                                      '0': {
                                        name: ['error']
                                      }
                                    }
                                  })
      end
    end

    context 'with deeply nested key' do
      it 'creates deep nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'a.b.c.d.e' => ['deep error'] })

        expect(target_hash).to eq({
                                    a: {
                                      b: {
                                        c: {
                                          d: {
                                            e: ['deep error']
                                          }
                                        }
                                      }
                                    }
                                  })
      end
    end

    context 'with existing structure' do
      before do
        target_hash[:address] = { city: ['existing error'] }
      end

      it 'preserves existing nested structure' do
        errors.send(:build_nested_hash, target_hash, { 'address.postal_code' => ['new error'] })

        expect(target_hash).to eq({
                                    address: {
                                      city: ['existing error'],
                                      postal_code: ['new error']
                                    }
                                  })
      end
    end

    context 'with custom separator' do
      it 'uses custom separator for splitting keys' do
        errors.send(:build_nested_hash, target_hash, { 'address/postal_code' => ['error'] }, '/')

        expect(target_hash).to eq({
                                    address: {
                                      postal_code: ['error']
                                    }
                                  })
      end
    end
  end
end
