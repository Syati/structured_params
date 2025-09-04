# rbs_inline: enabled
# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::ErrorFormatter do
  let(:invalid_params) do
    {
      name: '',
      email: '',
      address: {
        postal_code: '',
        prefecture: '',
        city: 'Tokyo',
        street: ''
      }
    }
  end

  let(:user_params) { UserParameter.new(invalid_params) }

  before do
    user_params.valid?
  end

  describe '#messages_with_json_pointer_keys' do
    it 'converts error keys to JSON Pointer format' do
      result = user_params.messages_with_json_pointer_keys

      expect(result.keys).to include('/name', '/email', '/address/postal_code', '/address/prefecture')
      expect(result['/name']).to eq(["can't be blank"])
      expect(result['/email']).to include("can't be blank") # emailには複数のエラーがあるのでincludeを使用
    end
  end

  describe '#full_messages_with_json_pointer_keys' do
    it 'returns full messages with JSON Pointer keys' do
      result = user_params.full_messages_with_json_pointer_keys

      expect(result).to be_a(Hash)
      expect(result.keys).to include('/name', '/email', '/address/postal_code', '/address/prefecture')
      expect(result['/name']).to include("Can't be blank") # ActiveModelは自動的に大文字で始める
    end
  end

  # Private methods are tested indirectly through public methods
  describe 'private utility methods' do
    it 'converts dot notation to JSON Pointer format through public methods' do
      result = user_params.messages_with_json_pointer_keys

      # Check that dot notation keys are properly converted to JSON Pointer format
      expect(result.keys).to all(start_with('/'))
      expect(result.keys).to include('/address/postal_code', '/address/prefecture')
    end

    it 'handles nested structures correctly' do
      result = user_params.messages_with_json_pointer_keys

      # Verify that nested address errors use JSON Pointer format
      nested_keys = result.keys.select { |key| key.include?('/address/') }
      expect(nested_keys).not_to be_empty
      expect(nested_keys).to all(match(%r{^/address/\w+$}))
    end
  end
end
