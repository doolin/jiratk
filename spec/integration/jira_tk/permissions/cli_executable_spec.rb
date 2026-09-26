# frozen_string_literal: true

require 'open3'

RSpec.describe JiraTk::Permissions::Cli do
  subject(:result) { Open3.capture3(runtime, RbConfig.ruby, 'exe/jira_permissions', *args, unsetenv_others: true) }

  let(:args) { ['--help'] }
  let(:runtime) { ENV.to_h.slice('PATH', 'TMPDIR', 'GEM_HOME', 'GEM_PATH', 'RUBYOPT', 'RUBYLIB', 'BUNDLE_GEMFILE') }

  it 'runs help without private configuration', :aggregate_failures do
    stdout, stderr, status = result
    expect(stdout).to include('Usage: jira_permissions', 'audit-results.md', '--apply')
    expect(stderr).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context 'with an unsupported option' do
    let(:args) { %w[scheme --apply] }

    it 'returns the CLI usage exit code', :aggregate_failures do
      stdout, stderr, status = result
      expect(stdout).to eq('')
      expect(stderr).to include('Invalid command options')
      expect(status.exitstatus).to eq(2)
    end
  end
end
