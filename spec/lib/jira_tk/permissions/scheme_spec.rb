# frozen_string_literal: true

require_relative '../../../support/permission_discovery'

RSpec.describe JiraTk::Permissions::Scheme do
  subject(:scheme) { client.project_scheme('PAH') }

  include_context 'with permission discovery'

  let(:client) { JiraTk::Permissions::Client.new(connection: connection) }

  before do
    jira_get('project/PAH/permissionscheme', { 'id' => 10_003, 'name' => 'Shared' })
  end

  it 'resolves the project scheme identity' do
    expect([scheme.id, scheme.name]).to eq(%w[10003 Shared])
  end

  it 'keeps connection details out of inspection' do
    expect(scheme.inspect).to eq('#<JiraTk::Permissions::Scheme id=10003>')
  end

  it 'keeps scheme and role IDs distinct even when their numeric values match' do
    stub_grants(grant_response(type: 'projectRole', value: '10003'))
    jira_get('role/10003', role_response(id: 10_003, name: 'atlassian-addons-project-access'))

    expect(scheme.grants.first['holder']).to include('id' => '10003', 'type' => 'projectRole', 'protected' => true)
  end

  context 'with different permissions and holder types' do
    before do
      jira_get('role/10076', role_response)
      stub_grants(grant_response(type: 'projectRole', parameter: 10_076, value: '10076'),
                  grant_response(id: 10_593),
                  grant_response(id: 10_594, type: 'projectRole', value: '10076').merge('permission' => 'ADD_COMMENTS'))
    end

    it 'finds the role grant for the requested permission' do
      grants = scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'projectRole', holder_id: 10_076)

      expect(grants.map { |grant| grant['id'] }).to eq(['10592'])
    end

    it 'matches absent application-role identities' do
      grants = scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'applicationRole', holder_id: nil)

      expect(grants.map { |grant| grant['id'] }).to eq(['10593'])
    end

    it 'fetches fresh grants for every lookup' do
      2.times { scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'projectRole', holder_id: 10_076) }

      expect(a_request(:get, "#{origin}/rest/api/3/permissionscheme/10003/permission")).to have_been_made.twice
    end
  end

  it 'accepts an explicitly empty grant collection' do
    jira_get('permissionscheme/10003/permission', { 'permissions' => [] })

    expect(scheme.grants).to eq([])
  end

  it 'reads and verifies an individual grant' do
    jira_get('permissionscheme/10003/permission/10592', grant_response)

    expect(client.grant(10_003, '10592')).to eq(
      'id' => '10592', 'permission' => 'ASSIGN_ISSUES', 'holder' => { 'type' => 'applicationRole', 'id' => nil,
                                                                      'supported' => true }
    )
  end

  it 'rejects the wrong grant on individual readback' do
    jira_get('permissionscheme/10003/permission/10592', grant_response(id: 999))

    expect { client.grant(10_003, 10_592) }.to raise_error(error_class, /Unexpected Jira grant ID/)
  end

  [nil, {}, { 'permissions' => {} }, { 'permissions' => [nil] },
   { 'permissions' => [{ 'id' => 1, 'permission' => nil, 'holder' => {} }] }].each do |invalid|
    it 'rejects malformed grant collections' do
      jira_get('permissionscheme/10003/permission', invalid)

      expect { scheme.grants }.to raise_error(error_class)
    end
  end

  it 'rejects duplicate grant IDs' do
    jira_get('permissionscheme/10003/permission', { 'permissions' => [grant_response, grant_response] })

    expect { scheme.grants }.to raise_error(error_class, /Duplicate Jira identities/)
  end

  describe 'holder identity' do
    context 'with a group name in the grant response' do
      before do
        stub_grants(grant_response(type: 'group', parameter: 'Humans'))
        jira_get('group/bulk', page([group_response]), params: { groupName: 'Humans', startAt: 0, maxResults: 50 })
      end

      it 'finds the grant by immutable ID' do
        grants = scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'group', holder_id: 'group-1')

        expect(grants.map { |grant| grant['id'] }).to eq(['10592'])
      end

      it 'does not treat the mutable name as an ID' do
        expect(scheme.find(permission: 'ASSIGN_ISSUES', holder_type: 'group', holder_id: 'Humans')).to eq([])
      end
    end

    [{ value: 'group-1' }, { parameter: 'Humans', value: 'group-1' }, { parameter: 'Humans' }].each do |fields|
      it 'resolves group ID, name, and the GET representation containing both' do
        stub_group
        jira_get('group/bulk', page([group_response]), params: { groupName: 'Humans', startAt: 0, maxResults: 50 })
        jira_get('permissionscheme/10003/permission', { 'permissions' => [grant_response(type: 'group', **fields)] })

        expect(scheme.grants.first['holder']).to eq('type' => 'group', 'id' => 'group-1', 'name' => 'Humans',
                                                    'supported' => true)
      end
    end

    it 'rejects a conflicting group name and ID' do
      stub_group
      jira_get('permissionscheme/10003/permission', {
                 'permissions' => [grant_response(type: 'group', value: 'group-1', parameter: 'Different')]
               })

      expect { scheme.grants }.to raise_error(error_class, /Group name and immutable ID disagree/)
    end

    [{}, { parameter: 10_076, value: 10_003 }].each do |fields|
      it 'rejects missing and conflicting project role IDs' do
        jira_get('permissionscheme/10003/permission',
                 { 'permissions' => [grant_response(type: 'projectRole', **fields)] })

        expect { scheme.grants }.to raise_error(error_class, /Missing or conflicting Jira role IDs/)
      end
    end

    it 'recognizes the protected role by its resolved name even at a different ID' do
      jira_get('role/10077', role_response(id: 10_077, name: 'atlassian-addons-project-access'))
      jira_get('permissionscheme/10003/permission',
               { 'permissions' => [grant_response(type: 'projectRole', parameter: '10077')] })

      expect(scheme.grants.first['holder']['protected']).to be(true)
    end

    it 'preserves absent, empty, and named application-role identities distinctly' do
      jira_get('permissionscheme/10003/permission', {
                 'permissions' => [grant_response, grant_response(id: 2, parameter: '', value: ''),
                                   grant_response(id: 3, parameter: 'jira-software', value: 'jira-software')]
               })

      expect(scheme.grants.map { |grant| grant['holder']['id'] }).to eq([nil, '', 'jira-software'])
    end

    it 'preserves unsupported holder types for explicit review' do
      jira_get('permissionscheme/10003/permission',
               { 'permissions' => [grant_response(type: 'futureKind', value: 'opaque-id')] })

      expect(scheme.grants.first['holder']).to eq('type' => 'futureKind', 'id' => 'opaque-id', 'supported' => false)
    end

    [{ parameter: 'one', value: 'two' }, { value: 123 }].each do |fields|
      it 'rejects invalid application-role identities' do
        jira_get('permissionscheme/10003/permission', { 'permissions' => [grant_response(**fields)] })

        expect { scheme.grants }.to raise_error(error_class, /Jira holder identit/)
      end
    end
  end
end
