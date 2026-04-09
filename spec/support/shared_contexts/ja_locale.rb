# frozen_string_literal: true

RSpec.shared_context 'with ja locale' do
  let(:ja_locale_files) { [] }
  let(:ja_overrides) { {} }

  around do |example|
    original_enforce = I18n.enforce_available_locales
    I18n.enforce_available_locales = false
    I18n.backend.reload!
    load_ja_locale_files(ja_locale_files)

    begin
      I18n.with_locale(:ja) do
        example.run
      end
    ensure
      I18n.enforce_available_locales = original_enforce
      I18n.backend.reload!
    end
  end

  def load_ja_locale_files(locale_files)
    base_file = File.expand_path('../locales/ja.yml', __dir__)
    files = locale_files.map do |name|
      File.expand_path("../locales/#{name}.ja.yml", __dir__)
    end
    I18n.backend.load_translations(base_file, *files)
    I18n.backend.store_translations(:ja, ja_overrides) unless ja_overrides.empty?
  end
end
