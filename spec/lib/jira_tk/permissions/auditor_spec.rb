# frozen_string_literal: true

require_relative '../../../support/permission_audit'

RSpec.describe JiraTk::Permissions::Auditor do
  subject(:auditor) do
    described_class.new(administrator: administrator, audit_client: audit_client,
                        expected_account_id: 'service-account')
  end

  include_context 'with a permission audit'

  context 'with the complete initial project inventory' do
    let(:projects) { %w[ADMIN BST DS FIN GEN PAH PLANT SCRUM TASKLETS] }

    before do
      stub_audit_inventory(projects.reverse.each_with_index.map { |key, index| audit_project(key, index + 1) })
      projects.each { |key| stub_audit_permissions(key, key == 'PAH') }
    end

    it 'passes only when the positive and all negative controls match', :aggregate_failures do
      report = auditor.audit

      expect(report.status).to eq('passed')
      expect(report.exit_status).to eq(0)
      expect(report.to_h['comparison']).to eq('status' => 'passed', 'mismatches' => [], 'unknowns' => [],
                                              'coverage_gaps' => [])
    end

    it 'uses all administrator-discovered projects, including denied ones' do
      expect(auditor.audit.to_h['projects'].map { |row| row['key'] }).to eq(projects)
    end

    it 'records the verified service identity and UTC timestamp' do
      expect(auditor.audit.to_h).to include(
        'identity' => { 'id' => 'service-account', 'active' => true, 'site_id' => Digest::SHA256.hexdigest(origin) },
        'timestamp' => '2026-09-26T12:00:00Z', 'permissions' => audit_keys
      )
    end

    it 'renders the requested six-column matrix in stable order' do
      lines = auditor.audit.matrix.lines.first(10).map(&:split)

      expect(lines).to eq([%w[PROJECT BROWSE CREATE EDIT TRANSITION COMMENT ASSIGN]] +
                         projects.map { |key| [key] + ([key == 'PAH' ? 'true' : 'false'] * 6) })
    end

    context 'with the known GEN assignment leak' do
      let(:mismatch) do
        { 'project' => 'GEN', 'permission' => 'ASSIGN_ISSUES', 'expected' => false, 'actual' => true }
      end

      before do
        stub_audit_permissions('GEN', false, 'ASSIGN_ISSUES' => { 'key' => 'ASSIGN_ISSUES', 'havePermission' => true })
      end

      it 'reports the negative-control mismatch', :aggregate_failures do
        report = auditor.audit

        expect(report.exit_status).to eq(1)
        expect(report.to_h['comparison']['mismatches']).to eq([mismatch])
      end
    end

    it 'reports loss of PAH comments as a positive-control regression' do
      stub_audit_permissions('PAH', true, 'ADD_COMMENTS' => { 'key' => 'ADD_COMMENTS', 'havePermission' => false })

      expect(auditor.audit.to_h['comparison']['mismatches']).to eq(
        [{ 'project' => 'PAH', 'permission' => 'ADD_COMMENTS', 'expected' => true, 'actual' => false }]
      )
    end

    it 'marks explicit subsets incomplete even when selected controls match', :aggregate_failures do
      report = auditor.audit(projects: %w[PAH GEN])

      expect(report.status).to eq('incomplete')
      expect(report.matrix).to include('unknown', 'Result: incomplete (subset scope)')
      expect(report.to_h['comparison']['coverage_gaps']).to include('key' => 'ADMIN', 'coverage' => 'not_selected')
    end

    it 'does not query unselected project permissions' do
      auditor.audit(projects: %w[PAH GEN])

      expect(a_request(:get, "#{audit_gateway}/rest/api/3/mypermissions")
        .with(query: permission_query('ADMIN'))).not_to have_been_made
    end

    context 'with a missing individual permission' do
      let(:unknown) { { 'project' => 'GEN', 'permission' => 'ASSIGN_ISSUES', 'error' => 'invalid_permission' } }

      before { stub_audit_permissions('GEN', false, 'ASSIGN_ISSUES' => nil) }

      it 'reports unknown access instead of denial', :aggregate_failures do
        report = auditor.audit

        expect(report.exit_status).to eq(2)
        expect(report.to_h['comparison']['unknowns']).to eq([unknown])
      end
    end

    it 'keeps known mismatches visible even when another cell is unknown' do
      stub_audit_permissions('PAH', false, 'ASSIGN_ISSUES' => nil)

      expect(auditor.audit.to_h['comparison']).to include('status' => 'incomplete',
                                                          'mismatches' => have_attributes(length: 5))
    end
  end

  context 'with changes to the project inventory' do
    before do
      stub_audit_permissions('PAH', true)
      stub_audit_permissions('NEW', false)
    end

    it 'includes newly discovered live projects as negative controls', :aggregate_failures do
      stub_audit_inventory([audit_project('PAH', 1), audit_project('NEW', 2)])
      report = auditor.audit(required_projects: %w[PAH])

      expect(report.status).to eq('passed')
      expect(report.to_h['projects'].first).to include('key' => 'NEW', 'new_project' => true, 'expected' => false)
    end

    it 'does not omit a new project discovered on a later page' do
      stub_audit_inventory([])
      stub_project_page('live', [audit_project('PAH', 1)], total: 2, last: false)
      stub_project_page('live', [audit_project('NEW', 2)], offset: 1, total: 2)

      expect(auditor.audit(required_projects: %w[PAH]).to_h['projects'].map { |row| row['key'] }).to eq(%w[NEW PAH])
    end

    it 'keeps missing required controls visible', :aggregate_failures do
      stub_audit_inventory([audit_project('PAH', 1)])
      report = auditor.audit

      expect(report.status).to eq('incomplete')
      expect(report.to_h['comparison']['coverage_gaps']).to include('key' => 'GEN', 'coverage' => 'missing')
    end

    it 'requires the positive control even when omitted from the required list' do
      stub_audit_inventory([audit_project('NEW', 1)])

      expect(auditor.audit(required_projects: []).to_h['comparison']['coverage_gaps'])
        .to eq([{ 'key' => 'PAH', 'coverage' => 'missing' }])
    end

    it 'does not certify an empty site inventory as isolated' do
      stub_audit_inventory([])

      expect(auditor.audit.status).to eq('incomplete')
    end

    it 'reports a requested project absent from discovery' do
      stub_audit_inventory([audit_project('PAH', 1)])

      expect(auditor.audit(projects: %w[GONE], required_projects: []).to_h['comparison']['coverage_gaps'])
        .to include('key' => 'GONE', 'coverage' => 'missing')
    end

    [%w[archived classic archived], %w[deleted classic deleted],
     %w[live next-gen unsupported], %w[live future-style unsupported]].each do |status, style, coverage|
      it "keeps #{status}/#{style} coverage incomplete", :aggregate_failures do
        stub_audit_inventory([audit_project('PAH', 1), audit_project('OLD', 2, status: status, style: style)])
        report = auditor.audit(required_projects: %w[PAH])

        expect(report.status).to eq('incomplete')
        expect(report.to_h['comparison']['coverage_gaps']).to eq([{ 'key' => 'OLD', 'coverage' => coverage }])
      end
    end
  end

  describe 'preconditions' do
    it 'does not include private connections in inspection' do
      expect(auditor.inspect).to eq('#<JiraTk::Permissions::Auditor>')
    end

    [nil, '', ' '].each do |id|
      it 'requires an expected service account before making requests' do
        expect do
          described_class.new(administrator: administrator, audit_client: audit_client, expected_account_id: id)
        end
          .to raise_error(error_class)
      end
    end

    [{ projects: [] }, { projects: 'PAH' }, { projects: %w[PAH PAH] }, { projects: ['../PAH'] },
     { required_projects: nil }, { required_projects: %w[PAH PAH] }, { positive: '' }].each do |options|
      it 'rejects invalid scope before discovery', :aggregate_failures do
        expect { auditor.audit(**options) }.to raise_error(error_class)
        expect(a_request(:get, "#{origin}/rest/api/3/myself")).not_to have_been_made
      end
    end

    it 'rejects the wrong service identity before collecting results', :aggregate_failures do
      stub_identity(base: audit_gateway, authorization: 'Bearer synthetic-bearer', id: 'different-account')

      expect { auditor.audit }.to raise_error(error_class, /Audit account or Jira site identity differs/)
      expect(a_request(:get, "#{audit_gateway}/rest/api/3/mypermissions")).not_to have_been_made
    end

    it 'fails closed when administrator inventory is incomplete' do
      stub_audit_inventory([])
      jira_get('project/search', page([], total: 3),
               params: { status: 'live', orderBy: 'key', startAt: 0, maxResults: 50 })

      expect { auditor.audit }.to raise_error(error_class, /Incomplete Jira pagination/)
    end
  end
end
