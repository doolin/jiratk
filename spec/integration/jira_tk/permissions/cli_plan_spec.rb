# frozen_string_literal: true

require_relative '../../../support/permission_plan'
require_relative '../../../support/permissions_cli'

RSpec.describe JiraTk::Permissions::Cli do
  include_context 'with a permission repair plan'
  include_context 'with permissions CLI output'

  let(:plan_args) do
    %w[plan --operation pah-assign-repair --account-id service-account --service-group-id service-group
       --broad-holder-json null] + ['--output', plan_path] + service_args
  end

  it 'saves the exact reviewable plan returned on stdout', :aggregate_failures do
    expect(cli.run(plan_args)).to eq(0)
    saved = JiraTk::Permissions::Plan.load(File.read(plan_path))
    expect(saved.to_h).to eq(JSON.parse(output.string))
    expect(saved.request['broad_grant']['holder']['id']).to be_nil
    expect(File.stat(plan_path).mode & 0o777).to eq(0o600)
  end

  it 'only reads Jira while preparing a plan', :aggregate_failures do
    cli.run(plan_args)
    expect(a_request(:post, /permissionscheme/)).not_to have_been_made
    expect(a_request(:delete, /permissionscheme/)).not_to have_been_made
  end

  it 'accepts an explicitly reviewed project scope', :aggregate_failures do
    expect(cli.run(plan_args + %w[--projects GEN,PAH])).to eq(0)
    expect(JSON.parse(output.string)['request']['scheme']['projects']).to eq(%w[GEN PAH])
  end

  it 'rejects unsupported operations before making requests', :aggregate_failures do
    args = plan_args.map { |value| value == 'pah-assign-repair' ? 'pah-isolation' : value }
    expect(cli.run(args)).to eq(2)
    expect(File).not_to exist(plan_path)
    expect(a_request(:any, /example|atlassian/)).not_to have_been_made
  end

  %w[malformed-secret 12].each do |holder|
    it 'rejects invalid broad holder identities without exposing input', :aggregate_failures do
      args = plan_args.map { |value| value == 'null' ? holder : value }
      expect(cli.run(args)).to eq(2)
      expect(errors.string).not_to include('malformed-secret')
      expect(File).not_to exist(plan_path)
    end
  end

  it 'preserves an existing reviewed file', :aggregate_failures do
    File.write(plan_path, 'previous plan')
    expect(cli.run(plan_args)).to eq(2)
    expect(File.read(plan_path)).to eq('previous plan')
    expect(errors.string).to eq("Unable to read or write command file\n")
  end
end
