# frozen_string_literal: true

require_relative '../../../support/permission_plan'
require_relative '../../../support/permissions_cli'

RSpec.describe JiraTk::Permissions::Cli do
  include_context 'with a permission repair plan'
  include_context 'with permissions CLI output'

  [[], ['help'], ['--help'], ['-h']].each do |args|
    it 'shows help without requiring credentials or making requests', :aggregate_failures do
      environment.clear
      expect(cli.run(args)).to eq(0)
      expect(output.string).to include('Usage:', '--apply', '--service-token-env')
      expect(a_request(:any, /example|atlassian/)).not_to have_been_made
    end
  end

  [%w[destroy], %w[scheme], %w[scheme --project PAH leftover], %w[scheme --apply],
   %w[scheme --project], %w[scheme --project PAH --project GEN],
   %w[audit --format yaml], %w[execute --app], %w[grants --password synthetic-secret]].each do |args|
    it 'rejects invalid input without echoing arguments or making requests', :aggregate_failures do
      expect(cli.run(args)).to eq(2)
      expect(errors.string).not_to be_empty
      expect(errors.string).not_to include('synthetic-secret')
      expect(output.string).to be_empty
      expect(a_request(:any, /example|atlassian/)).not_to have_been_made
    end
  end

  it 'returns a scheme and its normalized grants', :aggregate_failures do
    expect(cli.run(%w[scheme --project PAH])).to eq(0)
    expect(JSON.parse(output.string)).to include('id' => '10003', 'name' => 'GEN software permission scheme',
                                                 'grants' => include(include('id' => '10592')))
  end

  it 'lists all grants', :aggregate_failures do
    expect(cli.run(%w[grants --scheme 10003])).to eq(0)
    expect(JSON.parse(output.string).size).to eq(repair_grants.size)
  end

  it 'filters grants by exact permission', :aggregate_failures do
    expect(cli.run(%w[grants --scheme 10003 --permission ASSIGN_ISSUES])).to eq(0)
    expect(JSON.parse(output.string).map { |grant| grant['id'] }).to eq(%w[10532 10592])
  end

  it 'does not expose environment values through inspection' do
    expect(cli.inspect).to eq('#<JiraTk::Permissions::Cli>')
  end

  context 'with an injected administrator connection' do
    subject(:cli) do
      described_class.new(out: output, err: errors, environment: environment, administrator_connection: connection)
    end

    it 'uses that connection for discovery', :aggregate_failures do
      expect(cli.run(%w[grants --scheme 10003])).to eq(0)
      expect(a_request(:get, "#{origin}/rest/api/3/permissionscheme/10003/permission")).to have_been_made.once
    end
  end
end
