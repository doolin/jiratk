# frozen_string_literal: true

require_relative '../../../support/permission_audit'

RSpec.describe JiraTk::Permissions::PermissionCheck do
  subject(:result) { audit_client.my_permissions('GEN') }

  include_context 'with a permission audit'

  it 'retains legitimate denials as explicit false values' do
    stub_audit_permissions('GEN', false)

    expect(result.values).to eq([{ 'value' => false, 'error' => nil }] * 6)
  end

  [nil, [], {}, { 'key' => 'OTHER', 'havePermission' => false }, { 'key' => 'ASSIGN_ISSUES' },
   { 'key' => 'ASSIGN_ISSUES', 'havePermission' => 'false' },
   { 'key' => 'ASSIGN_ISSUES', 'havePermission' => 0 }].each do |entry|
    it 'preserves the other cells when one permission is missing or invalid', :aggregate_failures do
      stub_audit_permissions('GEN', true, 'ASSIGN_ISSUES' => entry)

      expect(result['ASSIGN_ISSUES']).to eq('value' => nil, 'error' => 'invalid_permission')
      expect(result['EDIT_ISSUES']).to eq('value' => true, 'error' => nil)
    end
  end

  [nil, [], {}, { 'permissions' => [] }].each do |body|
    it 'reports malformed whole responses as unknown results' do
      jira_get('mypermissions', body, base: audit_gateway, authorization: 'Bearer synthetic-bearer',
                                      params: permission_query('GEN'))

      expect(result.values).to eq([{ 'value' => nil, 'error' => 'request_failed' }] * 6)
    end
  end

  [301, 400, 401, 403, 404, 429, 500].each do |code|
    it "does not interpret HTTP #{code} as denial or include its body" do
      stub_request(:get, "#{audit_gateway}/rest/api/3/mypermissions")
        .with(query: permission_query('GEN')).to_return(status: code, body: 'synthetic-secret')

      expect(result.values).to eq([{ 'value' => nil, 'error' => 'request_failed' }] * 6)
    end
  end

  it 'reports transport failures as unknown results' do
    stub_request(:get, "#{audit_gateway}/rest/api/3/mypermissions").with(query: permission_query('GEN')).to_timeout

    expect(result.values).to eq([{ 'value' => nil, 'error' => 'request_failed' }] * 6)
  end

  it 'reports invalid JSON as unknown results' do
    stub_request(:get, "#{audit_gateway}/rest/api/3/mypermissions")
      .with(query: permission_query('GEN')).to_return(status: 200, body: 'not JSON: synthetic-secret')

    expect(result.values).to eq([{ 'value' => nil, 'error' => 'request_failed' }] * 6)
  end

  it 'rejects invalid project input instead of returning an unknown audit' do
    expect { audit_client.my_permissions('../GEN') }.to raise_error(error_class, /Invalid Jira project key/)
  end
end
