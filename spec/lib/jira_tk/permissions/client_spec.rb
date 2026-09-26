# frozen_string_literal: true

require_relative '../../../support/permission_discovery'

RSpec.describe JiraTk::Permissions::Client do
  subject(:client) { described_class.new(connection: connection) }

  include_context 'with permission discovery'

  it 'keeps configuration out of inspection' do
    expect(client.inspect).to eq('#<JiraTk::Permissions::Client>')
  end

  describe 'identity verification' do
    let(:gateway) { 'https://api.atlassian.com/ex/jira/00000000-1111-2222-3333-444444444444' }
    let(:audit_connection) { JiraTk::Permissions::Connection.service_account(base_url: gateway, token: 'synthetic-bearer') }
    let(:auditor) { described_class.new(connection: audit_connection) }

    it 'verifies the expected service account at the same site through its own gateway connection' do
      stub_identity
      stub_identity(base: gateway, authorization: 'Bearer synthetic-bearer', id: 'service-account')

      expect(client.verify_audit_identity(audit_client: auditor, expected_account_id: 'service-account'))
        .to eq('id' => 'service-account', 'active' => true, 'site_id' => Digest::SHA256.hexdigest(origin))
    end

    [['wrong-account', 'service-account', 'https://permissions.example.test'],
     ['admin-account', 'admin-account', 'https://permissions.example.test'],
     ['service-account', 'service-account', 'https://another.example.test']].each do |actual, expected, site|
      it 'rejects an unexpected account, reused administrator, or different site' do
        stub_identity
        stub_identity(base: gateway, authorization: 'Bearer synthetic-bearer', id: actual, site: site)

        expect { client.verify_audit_identity(audit_client: auditor, expected_account_id: expected) }
          .to raise_error(error_class, 'Audit account or Jira site identity differs')
      end
    end

    it 'rejects an inactive authenticated account' do
      jira_get('myself', { 'accountId' => 'service-account', 'active' => false })

      expect { client.identity }.to raise_error(error_class, /inactive/)
    end

    [nil, {}, { 'accountId' => 'user' }, { 'accountId' => ' ', 'active' => true }].each do |invalid|
      it 'rejects missing identity fields' do
        jira_get('myself', invalid)

        expect { client.identity }.to raise_error(error_class)
      end
    end
  end

  describe 'project inventory' do
    let(:project) { { 'id' => 10, 'key' => 'PAH', 'name' => 'Production', 'style' => 'classic' } }

    before do
      jira_get('mypermissions', { 'permissions' => { 'ADMINISTER' => { 'havePermission' => true } } },
               params: { permissions: 'ADMINISTER' })
      %w[live archived deleted].each do |status|
        jira_get('project/search', page([]), params: { status: status, orderBy: 'key', startAt: 0, maxResults: 50 })
      end
    end

    context 'with a shared scheme and multiple project pages' do
      before do
        stub_project_page('live', [project], total: 2, last: false)
        stub_project_page('live', [project.merge('id' => '11', 'key' => 'GEN')], offset: 1, total: 2)
        stub_project_page('archived', [project.merge('id' => 12, 'key' => 'OLD')])
        stub_project_page('deleted', [project.merge('id' => 13, 'key' => 'GONE')])
        %w[PAH GEN OLD].each do |key|
          jira_get("project/#{key}/permissionscheme", { 'id' => 10_003, 'name' => 'Shared' })
        end
      end

      it 'maps all discovered shared scheme associations' do
        expect(client.inventory['scheme_projects']).to eq('10003' => %w[PAH GEN OLD])
      end

      it 'preserves normalized identities and explicit project coverage' do
        projects = client.inventory['projects']

        expect(projects.map { |item| item.values_at('id', 'key', 'status', 'scheme_id', 'coverage') })
          .to eq([%w[10 PAH live 10003 available], %w[11 GEN live 10003 available],
                  %w[12 OLD archived 10003 available], ['13', 'GONE', 'deleted', nil, 'unsupported']])
      end
    end

    it 'reports team-managed projects without attempting scheme discovery' do
      stub_project_page('live', [project.merge('style' => 'next-gen')])

      expect(client.inventory['projects']).to contain_exactly(
        'id' => '10', 'key' => 'PAH', 'name' => 'Production', 'style' => 'next-gen', 'status' => 'live',
        'scheme_id' => nil, 'coverage' => 'unsupported'
      )
    end

    [false, nil, 'true'].each do |permission|
      it 'refuses to call a restricted project listing complete' do
        jira_get('mypermissions', { 'permissions' => { 'ADMINISTER' => { 'havePermission' => permission } } },
                 params: { permissions: 'ADMINISTER' })

        expect { client.projects }.to raise_error(error_class, /requires Administer Jira/)
      end
    end

    it 'rejects duplicate projects across status inventories' do
      %w[live archived].each do |status|
        jira_get('project/search', page([project]),
                 params: { status: status, orderBy: 'key', startAt: 0, maxResults: 50 })
      end

      expect { client.projects }.to raise_error(error_class, /Duplicate Jira identities/)
    end

    it 'rejects different IDs with the same project key' do
      jira_get('project/search', page([project, project.merge('id' => 11)]),
               params: { status: 'live', orderBy: 'key', startAt: 0, maxResults: 50 })

      expect { client.projects }.to raise_error(error_class, /Duplicate Jira identities/)
    end

    [{ 'id' => nil }, { 'id' => 0 }, { 'id' => '01' }, { 'id' => 1.5 }, { 'key' => '../PAH' },
     { 'name' => nil }, { 'style' => nil }].each do |invalid|
      it 'rejects malformed project identities and metadata' do
        jira_get('project/search', page([project.merge(invalid)]),
                 params: { status: 'live', orderBy: 'key', startAt: 0, maxResults: 50 })

        expect { client.projects }.to raise_error(error_class)
      end
    end
  end

  describe 'group discovery' do
    it 'resolves immutable IDs' do
      stub_group

      expect(client.group(id: 'group-1')).to eq('id' => 'group-1', 'name' => 'Humans')
    end

    it 'resolves mutable names to immutable IDs' do
      jira_get('group/bulk', page([group_response]), params: { groupName: 'Humans', startAt: 0, maxResults: 50 })

      expect(client.group(name: 'Humans')).to eq('id' => 'group-1', 'name' => 'Humans')
    end

    [{}, { id: 'group-1', name: 'Humans' }].each do |args|
      it 'requires exactly one group selector' do
        expect { client.group(**args) }.to raise_error(error_class, /Provide one group/)
      end
    end

    [[], [{ 'groupId' => 'wrong-id', 'name' => 'Humans' }],
     [{ 'groupId' => 'group-1', 'name' => 'Humans' }, { 'groupId' => 'group-1', 'name' => 'Humans' }]].each do |values|
      it 'rejects missing, mismatched, or ambiguous group IDs' do
        jira_get('group/bulk', page(values), params: { groupId: 'group-1', startAt: 0, maxResults: 50 })

        expect { client.group(id: 'group-1') }.to raise_error(error_class, /missing or ambiguous/)
      end
    end

    it 'rejects a mismatched group name' do
      jira_get('group/bulk', page([group_response(name: 'Different')]),
               params: { groupName: 'Humans', startAt: 0, maxResults: 50 })

      expect { client.group(name: 'Humans') }.to raise_error(error_class, /missing or ambiguous/)
    end

    it 'examines all group-resolution pages before deciding a match is unique' do
      jira_get('group/bulk', page([group_response], total: 2, last: false),
               params: { groupName: 'Humans', startAt: 0, maxResults: 50 })
      jira_get('group/bulk', page([group_response(id: 'group-2')], offset: 1, total: 2),
               params: { groupName: 'Humans', startAt: 1, maxResults: 50 })

      expect { client.group(name: 'Humans') }.to raise_error(error_class, /missing or ambiguous/)
    end

    it 'reads every membership page including inactive users and omits personal fields' do
      stub_group_members([{ 'accountId' => 'first', 'active' => true, 'emailAddress' => 'omit' }],
                         total: 2, last: false)
      stub_group_members([{ 'accountId' => 'second', 'active' => false }], offset: 1, total: 2)

      expect(client.group_members('group-1')).to eq([{ 'id' => 'first', 'active' => true },
                                                     { 'id' => 'second', 'active' => false }])
    end

    it 'reads account memberships from the unpaginated array endpoint' do
      jira_get('user/groups', [group_response, group_response(id: 'group-2', name: 'Ticket managers')],
               params: { accountId: 'service-account' })

      expect(client.account_groups('service-account')).to eq(
        [{ 'id' => 'group-1', 'name' => 'Humans' }, { 'id' => 'group-2', 'name' => 'Ticket managers' }]
      )
    end

    it 'rejects incomplete account group data' do
      jira_get('user/groups', [{ 'name' => 'Humans' }], params: { accountId: 'service-account' })

      expect { client.account_groups('service-account') }.to raise_error(error_class)
    end
  end

  describe 'project roles' do
    it 'normalizes numeric role IDs' do
      jira_get('role/10076', role_response)

      expect(client.role('10076')).to eq('id' => '10076', 'name' => 'Ticket Manager')
    end

    it 'rejects an unexpected role identity' do
      jira_get('role/10076', role_response(id: 10_003))

      expect { client.role(10_076) }.to raise_error(error_class, /Unexpected Jira role ID/)
    end

    context 'with direct users and group actors' do
      let(:expected_role) do
        { 'id' => '10076', 'name' => 'Ticket Manager', 'actors' => [
          { 'actor_id' => '1', 'type' => 'group', 'id' => 'group-1', 'name' => 'Humans' },
          { 'actor_id' => '2', 'type' => 'user', 'id' => 'service-account' }
        ] }
      end

      before do
        stub_role_actors(
          { 'id' => 1, 'type' => 'atlassian-group-role-actor', 'actorGroup' => group_response },
          { 'id' => 2, 'type' => 'atlassian-user-role-actor', 'actorUser' => { 'accountId' => 'service-account' } }
        )
      end

      it 'discovers their immutable identities' do
        expect(client.role_actors('PAH', 10_076)).to eq(expected_role)
      end
    end

    it 'rejects unknown actor kinds' do
      jira_get('project/PAH/role/10076', role_response.merge('actors' => [{ 'id' => 1, 'type' => 'unknown' }]))

      expect { client.role_actors('PAH', 10_076) }.to raise_error(error_class, /Unsupported Jira role actor/)
    end

    it 'rejects name-only actors instead of treating a group name as its ID' do
      stub_role_actors('id' => 1, 'type' => 'atlassian-group-role-actor', 'actorGroup' => { 'name' => 'Humans' })

      expect { client.role_actors('PAH', 10_076) }.to raise_error(error_class)
    end
  end
end
