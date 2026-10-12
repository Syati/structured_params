# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StructuredParams::OpenAPI::DriftCheck::Result do
  def issue(kind, path, message)
    StructuredParams::OpenAPI::DriftCheck::Issue.new(kind: kind, path: path, message: message)
  end

  let(:parameter_class) { Class.new(StructuredParams::Params) }
  let(:error) { issue(:type_mismatch, 'name', 'wrong type') }
  let(:skipped_issue) { issue(:unsupported, 'tags', 'oneOf is outside the supported drift-check scope') }
  let(:ignored_issue) { issue(:missing_attribute, 'extra', 'schema property has no matching attribute declaration') }

  before { stub_const('ResultSpecParameter', parameter_class) }

  describe '#valid?' do
    it 'is true without errors, even with skipped or ignored findings' do
      expect(described_class.new(parameter_class, [], [skipped_issue], [ignored_issue])).to be_valid
    end

    it 'is false with errors' do
      expect(described_class.new(parameter_class, [error], [], [])).not_to be_valid
    end
  end

  describe '#to_message' do
    it 'returns an empty string when nothing is reported' do
      expect(described_class.new(parameter_class, [], [], []).to_message).to eq('')
    end

    it 'lists errors and skipped findings under the class name' do
      result = described_class.new(parameter_class, [error], [skipped_issue], [ignored_issue])

      expect(result.to_message).to eq(<<~MESSAGE.chomp)
        ResultSpecParameter
        OpenAPI drift detected:
        - name: wrong type
        OpenAPI checks skipped:
        - tags: oneOf is outside the supported drift-check scope
      MESSAGE
    end

    it 'omits the errors section when valid' do
      result = described_class.new(parameter_class, [], [skipped_issue], [])

      expect(result.to_message).not_to include('drift detected')
      expect(result.to_message).to include('OpenAPI checks skipped')
    end

    it 'falls back to inspect for anonymous classes' do
      anonymous = Class.new(StructuredParams::Params)
      result = described_class.new(anonymous, [error], [], [])

      expect(result.to_message).to start_with(anonymous.inspect)
    end
  end

  describe '#to_report' do
    it 'returns an empty string without skipped or ignored findings' do
      expect(described_class.new(parameter_class, [error], [], []).to_report).to eq('')
    end

    it 'lists skipped and ignored findings but not errors' do
      result = described_class.new(parameter_class, [error], [skipped_issue], [ignored_issue])

      expect(result.to_report).to eq(<<~REPORT.chomp)
        ResultSpecParameter
        OpenAPI checks skipped:
        - tags: oneOf is outside the supported drift-check scope
        OpenAPI findings ignored:
        - extra: schema property has no matching attribute declaration
      REPORT
    end
  end
end
