# frozen_string_literal: true

require_relative '../../../support/permission_plan'
require_relative '../../../support/permissions_cli'

RSpec.describe JiraTk::Permissions::Cli do
  include_context 'with a permission repair plan'
  include_context 'with permissions CLI output'

  let(:audit_args) { ['audit', '--account-id', 'service-account'] + service_args }
  let(:report_path) { File.join(directory, 'audit-results.md') }

  before { stub_const('JiraTk::Permissions::MarkdownFile::DEFAULT_PATH', report_path) }

  it 'saves a mismatch by default through the Markdown adapter', :aggregate_failures do
    expect(cli.run(audit_args)).to eq(1)
    expect(output.string).to include('PROJECT', 'BROWSE', 'COMMENT', 'Result: mismatch (all scope)')
    evidence = File.read(report_path)
    expect(evidence).to include(output.string.strip, 'service-account', 'site_id', '2026-09-26T12:00:00Z',
                                'coverage', 'mismatches', 'ASSIGN_ISSUES')
  end

  it 'excludes credentials and configuration from saved evidence', :aggregate_failures do
    cli.run(audit_args)
    expect(File.read(report_path)).not_to include('synthetic', origin, audit_gateway, 'SERVICE_TOKEN')
    expect(errors.string).to be_empty
  end

  it 'returns passed evidence and JSON without modifying the collection API', :aggregate_failures do
    repair_projects.each { |key| stub_audit_permissions(key, key == 'PAH') }
    expect(cli.run(audit_args + %w[--format json])).to eq(0)
    expect(JSON.parse(output.string)['comparison']).to include('status' => 'passed', 'mismatches' => [],
                                                               'unknowns' => [])
    expect(File.read(report_path)).to include('Result: passed (all scope)')
  end

  it 'retains unknown cells and incomplete status in a selected audit', :aggregate_failures do
    expect(cli.run(audit_args + %w[--projects PAH,GEN --format json])).to eq(2)
    data = JSON.parse(output.string)
    expect(data['scope']).to include('mode' => 'subset', 'requested_projects' => %w[GEN PAH])
    expect(data.dig('comparison', 'unknowns')).to include(include('error' => 'not_selected'))
    expect(File.read(report_path)).to include('unknown', 'not_selected', 'Result: incomplete (subset scope)')
  end

  it 'saves request failures as unknown rather than denied', :aggregate_failures do
    stub_request(:get, "#{audit_gateway}/rest/api/3/mypermissions").with(query: permission_query('PAH'))
                                                                   .to_return(status: 403, body: 'private')
    expect(cli.run(audit_args)).to eq(2)
    expect(File.read(report_path)).to include('request_failed', 'unknown')
    expect(File.read(report_path)).not_to include('private')
  end

  it 'supports an alternate output path', :aggregate_failures do
    target = File.join(directory, 'other.md')
    expect(cli.run(audit_args + ['--audit-output', target])).to eq(1)
    expect(File.read(target)).to include('Result: mismatch')
    expect(File).not_to exist(report_path)
  end

  it 'reports storage failure without changing the observed audit result', :aggregate_failures do
    expect(cli.run(audit_args + ['--audit-output', File.join(directory, 'missing', 'report.md')])).to eq(2)
    expect(output.string).to include('Result: mismatch')
    expect(errors.string).to include('Unable to save audit evidence')
    expect(File).not_to exist(report_path)
  end

  [nil, '', '  '].each do |token|
    it 'rejects absent service credentials before requests or saving', :aggregate_failures do
      environment['SERVICE_TOKEN'] = token
      expect(cli.run(audit_args)).to eq(2)
      expect(output.string).to be_empty
      expect(File).not_to exist(report_path)
      expect(a_request(:any, /example|atlassian/)).not_to have_been_made
    end
  end

  it 'accepts environment names rather than a pasted token', :aggregate_failures do
    expect(cli.run(%w[audit --account-id service-account --service-url-env SERVICE_URL
                      --service-token-env pasted.token])).to eq(2)
    expect(errors.string).to eq("Expected an environment variable name\n")
  end

  it 'rejects an invalid service endpoint without disclosing its value', :aggregate_failures do
    environment['SERVICE_URL'] = 'http://private-endpoint'
    expect(cli.run(audit_args)).to eq(2)
    expect(errors.string).not_to include('private-endpoint')
    expect(File).not_to exist(report_path)
  end

  it 'does not overwrite a previous report after an identity failure', :aggregate_failures do
    File.write(report_path, 'previous report')
    stub_identity(base: audit_gateway, authorization: 'Bearer synthetic-bearer', id: 'wrong-account')
    expect(cli.run(audit_args)).to eq(2)
    expect(output.string).to be_empty
    expect(File.read(report_path)).to eq('previous report')
  end

  context 'with an alternate adapter' do
    subject(:cli) do
      described_class.new(out: output, err: errors, environment: environment,
                          persistence: JiraTk::Permissions::Persistence.new(adapter: adapter))
    end

    let(:adapter) { instance_spy(JiraTk::Permissions::MarkdownFile) }

    it 'passes the real report through the interface without filesystem writes', :aggregate_failures do
      expect(cli.run(audit_args)).to eq(1)
      expect(adapter).to have_received(:save).with(instance_of(JiraTk::Permissions::AuditReport)) do |report|
        expect(report.status).to eq('mismatch')
      end
      expect(Dir.children(directory)).to be_empty
    end
  end
end
