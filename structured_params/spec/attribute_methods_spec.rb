# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::AttributeMethods do
  describe 'before_type_cast readers' do
    context 'with primitive attribute' do
      subject(:params) { UserParameter.new(age: '42abc') }

      it 'returns type-cast value from reader' do
        expect(params.age).to eq(42)
      end

      it 'returns raw input from before_type_cast reader' do
        expect(params.age_before_type_cast).to eq('42abc')
      end
    end

    context 'with nil input' do
      subject(:params) { UserParameter.new(age: nil) }

      it 'returns nil from before_type_cast reader' do
        expect(params.age_before_type_cast).to be_nil
      end
    end

    context 'with string attribute' do
      subject(:params) { UserParameter.new(name: 'Tanaka Taro') }

      it 'defines before_type_cast reader for declared attribute' do
        expect(params).to respond_to(:name_before_type_cast)
      end

      it 'returns same value for string type' do
        expect(params.name_before_type_cast).to eq('Tanaka Taro')
      end
    end
  end
end
