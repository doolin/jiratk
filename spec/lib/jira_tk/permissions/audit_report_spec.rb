# frozen_string_literal: true

require_relative '../../../support/permission_audit'

RSpec.describe JiraTk::Permissions::AuditReport do
  subject(:report) do
    JiraTk::Permissions::Auditor.new(administrator: administrator, audit_client: audit_client,
                                     expected_account_id: 'service-account').audit(required_projects: %w[PAH])
  end

  include_context 'with a permission audit'

  before do
    stub_audit_inventory([audit_project('PAH', 1)])
    stub_audit_permissions('PAH', true)
  end

  it 'returns independent output data that cannot alter the captured evidence', :aggregate_failures do
    data = report.to_h
    data['projects'].first['permissions']['ADD_COMMENTS']['value'] = false
    data['identity']['id'] = 'different-account'

    expect(report.status).to eq('passed')
    expect(report.to_h['identity']['id']).to eq('service-account')
  end

  it 'does not include response metadata in serialized output' do
    stub_audit_permissions('PAH', true, 'unrequested' => { 'cookie' => 'synthetic-secret' })

    expect(JSON.generate(report.to_h)).not_to include('synthetic', 'Authorization', 'cookie', 'baseUrl', 'emailAddress')
  end

  context 'with additional fields supplied at the report boundary' do
    let(:data) { report.to_h }
    let(:copy) do
      described_class.new(identity: data['identity'], scope: data['scope'], rows: data['projects'],
                          timestamp: data['timestamp'])
    end

    before do
      data['identity']['token'] = 'synthetic-secret'
      data['scope']['token'] = 'synthetic-secret'
      data['projects'].first['raw'] = 'synthetic-secret'
      data['projects'].first['permissions']['EDIT_ISSUES']['raw'] = 'synthetic-secret'
    end

    it 'allowlists output fields instead of retaining caller metadata' do
      expect(copy.to_h.to_json).not_to include('synthetic-secret', 'token', 'raw')
    end

    it 'captures evidence independently of its input' do
      saved = copy
      data['projects'].first['permissions']['EDIT_ISSUES']['value'] = false

      expect(saved.status).to eq('passed')
    end
  end
end
