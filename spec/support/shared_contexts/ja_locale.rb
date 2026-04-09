# frozen_string_literal: true

RSpec.shared_context 'with ja locale' do
  let(:ja_locale_files) { [] }

  around do |example|
    original_enforce = I18n.enforce_available_locales
    I18n.enforce_available_locales = false
    I18n.backend.reload!
    load_ja_locale_files(ja_locale_files)
    I18n.with_locale(:ja) do
      example.run
    end
    I18n.enforce_available_locales = original_enforce
    I18n.backend.reload!
  end

  def load_ja_locale_files(locale_files)
    files = locale_files.map do |name|
      File.expand_path("../locales/#{name}.ja.yml", __dir__)
    end
    I18n.backend.load_translations(*files) unless files.empty?
  end
end
