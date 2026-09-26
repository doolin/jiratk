# frozen_string_literal: true

require 'open3'

RSpec.describe JiraTk::Permissions do
  subject(:load_result) { Open3.capture3(RbConfig.ruby, '-Ilib', '-e', script) }

  let(:script) do
    <<~RUBY
      require 'jiratk/permissions'
      abort 'Optional dependency loaded' if $LOADED_FEATURES.any? { |path| path.match?(/aws-sdk|googleauth|google-apis/) }
      abort 'Permission client unavailable' unless defined?(JiraTk::Permissions::Client)
    RUBY
  end

  it 'loads without optional AWS and Google dependencies' do
    expect(load_result).to match(['', '', be_success])
  end
end
