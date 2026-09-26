# frozen_string_literal: true

require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::Planner do
  subject(:plan) { planner.pah_assign_repair(**repair_options) }

  include_context 'with a permission repair plan'

  let(:planner) { described_class.new(administrator: administrator, audit_client: audit_client) }

  it 'stops on an incomplete audit' do
    stub_audit_permissions('PAH', true, 'ADD_COMMENTS' => nil)

    expect { plan }.to raise_error(error_class, /complete permission audit/)
  end

  it 'rejects loss of PAH comments' do
    stub_audit_permissions('PAH', true, 'ADD_COMMENTS' => { 'key' => 'ADD_COMMENTS', 'havePermission' => false })

    expect { plan }.to raise_error(error_class, /Initial PAH or GEN controls differ/)
  end

  it 'rejects other GEN access requiring a broader repair' do
    stub_audit_permissions('GEN', true)

    expect { plan }.to raise_error(error_class, /Initial PAH or GEN controls differ/)
  end

  it 'rejects a different scheme name' do
    jira_get('project/PAH/permissionscheme', { 'id' => 10_003, 'name' => 'Renamed' })

    expect { plan }.to raise_error(error_class, /Expected scheme or role identity differs/)
  end

  it 'rejects a different Ticket Manager role name' do
    jira_get('role/10076', role_response(name: 'Other role'))

    expect { plan }.to raise_error(error_class, /Expected scheme or role identity differs/)
  end

  it 'rejects an undeclared shared project' do
    jira_get('project/ADMIN/permissionscheme', { 'id' => 10_003, 'name' => 'GEN software permission scheme' })

    expect { plan }.to raise_error(error_class, /scheme associations differ/)
  end

  context 'with an explicitly reviewed additional shared project' do
    before do
      jira_get('project/ADMIN/permissionscheme', { 'id' => 10_003, 'name' => 'GEN software permission scheme' })
      stub_repair_role('ADMIN', [])
    end

    it 'requires its assignment denial while preserving the other controls' do
      expanded = planner.pah_assign_repair(**repair_options, projects: %w[PAH GEN ADMIN])

      expect(expanded.to_h['controls']['after_delete']['ADMIN']).to include(
        'ASSIGN_ISSUES' => false, 'EDIT_ISSUES' => true
      )
    end
  end

  it 'rejects a missing explicit PAH role grant even while broad access keeps the matrix green' do
    stub_grants(*repair_grants.reject { |grant| grant['permission'] == 'ADD_COMMENTS' })

    expect { plan }.to raise_error(error_class, /missing another PAH permission/)
  end

  it 'rejects a missing protected grant' do
    stub_grants(*repair_grants.reject { |grant| grant['id'] == 10_532 })

    expect { plan }.to raise_error(error_class, /protected addon grant differs/)
  end

  it 'refuses a deletion ID that now belongs to a protected role' do
    remaining = repair_grants.reject { |grant| grant['id'] == 10_592 }
    stub_grants(*remaining, role_grant(10_592, 'ASSIGN_ISSUES', role: '10003'))

    expect { plan }.to raise_error(error_class, /Deletion target differs/)
  end

  it 'refuses to retarget an equivalent grant with a different ID' do
    stub_grants(*repair_grants.reject { |grant| grant['id'] == 10_592 }, grant_response(id: 10_593))

    expect { plan }.to raise_error(error_class, /Broad grant identity differs/)
  end

  it 'refuses ambiguous duplicate broad grants' do
    stub_grants(*repair_grants, grant_response(id: 10_593))

    expect { plan }.to raise_error(error_class, /Required grant is ambiguous/)
  end

  it 'refuses duplicate replacement grants' do
    stub_grants(*repair_grants, human_grant, human_grant.merge('id' => 10_801))

    expect { plan }.to raise_error(error_class, /Required grant is ambiguous/)
  end

  it 'distinguishes an absent application-role identity from an empty one' do
    expect { planner.pah_assign_repair(**repair_options, broad_holder_id: '') }
      .to raise_error(error_class, /Deletion target differs/)
  end

  it 'requires the exact caller-declared named application role' do
    stub_grants(*repair_grants.reject { |grant| grant['id'] == 10_592 }, grant_response(value: 'jira-software'))
    named = planner.pah_assign_repair(**repair_options, broad_holder_id: 'jira-software')

    expect(named.to_h['steps'][6]['expected_grant']['holder']['id']).to eq('jira-software')
  end

  it 'rejects a renamed human group' do
    stub_repair_group(human_group_id, 'Other humans', [])

    expect { plan }.to raise_error(error_class, /Group identity differs/)
  end

  it 'rejects a target account included in the human replacement group' do
    stub_repair_group(human_group_id, 'jira-project-users', [{ 'accountId' => 'service-account', 'active' => true }])
    jira_get('user/groups', [group_response(id: 'service-group', name: 'pah-ticket-managers'),
                             group_response(id: human_group_id, name: 'jira-project-users')],
             params: { accountId: 'service-account' })

    expect { plan }.to raise_error(error_class, /Service-account group membership differs/)
  end

  it 'rejects a target account absent from its intended service group' do
    stub_repair_group('service-group', 'pah-ticket-managers', [])
    jira_get('user/groups', [], params: { accountId: 'service-account' })

    expect { plan }.to raise_error(error_class, /Service-account group membership differs/)
  end

  it 'rejects conflicting membership endpoints' do
    jira_get('user/groups', [], params: { accountId: 'service-account' })

    expect { plan }.to raise_error(error_class, /membership evidence disagree/)
  end

  it 'rejects an inactive membership for the active audit account' do
    stub_repair_group('service-group', 'pah-ticket-managers', [{ 'accountId' => 'service-account', 'active' => false }])

    expect { plan }.to raise_error(error_class, /membership evidence disagree/)
  end

  it 'rejects conflicting names in account and group membership evidence' do
    jira_get('user/groups', [group_response(id: 'service-group', name: 'Different')],
             params: { accountId: 'service-account' })

    expect { plan }.to raise_error(error_class, /membership evidence disagree/)
  end

  it 'requires the intended service group actor in PAH' do
    stub_repair_role('PAH', [])

    expect { plan }.to raise_error(error_class, /lacks the intended service group/)
  end

  it 'rejects a role whose project-specific name differs' do
    jira_get('project/GEN/role/10076', role_response(name: 'Different').merge('actors' => []))

    expect { plan }.to raise_error(error_class, /Shared project role identities differ/)
  end

  context 'with direct negative-project actors' do
    let(:actor) { { 'id' => 2, 'type' => 'atlassian-user-role-actor', 'actorUser' => { 'accountId' => account } } }
    let(:account) { 'service-account' }

    before { stub_repair_role('GEN', [actor]) }

    it 'rejects the service account holding a shared negative role' do
      expect { plan }.to raise_error(error_class, /holds Ticket Manager in a negative-control project/)
    end

    context 'with another account' do
      let(:account) { 'human-account' }

      it 'retains the actor without assigning its access to the service account' do
        expect(plan.to_h['evidence']['project_roles'].first['actors'].first['id']).to eq('human-account')
      end
    end
  end

  context 'with a negative-project group actor' do
    before do
      stub_repair_group('other-group', 'Other group', [{ 'accountId' => 'human-account', 'active' => true }])
      stub_repair_role('GEN', [group_actor('other-group', 'Other group')])
    end

    it 'records its complete membership for later drift checks' do
      expect(plan.to_h['evidence']['groups'].find { |group| group['id'] == 'other-group' }['members'])
        .to eq([{ 'id' => 'human-account', 'active' => true }])
    end

    it 'rejects indirect service-account access' do
      stub_repair_role('GEN', [group_actor('service-group', 'pah-ticket-managers')])

      expect { plan }.to raise_error(error_class, /holds Ticket Manager in a negative-control project/)
    end

    it 'rejects disagreement between actor and resolved group names' do
      stub_repair_role('GEN', [group_actor('other-group', 'Different group')])

      expect { plan }.to raise_error(error_class, /Group identity differs/)
    end
  end
end
