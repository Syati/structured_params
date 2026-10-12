# frozen_string_literal: true

require 'spec_helper'
require 'open3'

# rubocop:disable-next RSpec/DescribeClass
RSpec.describe 'loading the OpenAPI drift-check rake task' do
  it 'does not raise when Rake is defined without its DSL mixed into main' do
    # Thor::Actions (used by Rails::Command, e.g. `rails runner`/`rails console`)
    # requires 'rake/file_utils_ext' directly. That defines the top-level
    # `Rake` constant without loading rake/dsl_definition.rb, so `namespace`
    # and `task` are never mixed into `main`. Reproduce that exact condition
    # instead of a full `require 'rake'`, which mixes the DSL in as a side effect.
    lib_path = File.expand_path('../../lib', __dir__)
    script = "require 'rake/file_utils_ext'; require 'structured_params/openapi'; puts 'ok'"

    output, status = Open3.capture2e('bundle', 'exec', 'ruby', '-I', lib_path, '-e', script)

    expect(status).to be_success, output
    expect(output).to include('ok')
  end
end
