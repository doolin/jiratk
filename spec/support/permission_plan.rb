# frozen_string_literal: true

require_relative 'permission_audit'

RSpec.shared_context 'with a permission repair plan' do
  include_context 'with a permission audit'

  let(:repair_options) { { account_id: 'service-account', service_group_id: 'service-group', broad_holder_id: nil } }
  let(:repair_projects) { %w[ADMIN BST DS FIN GEN PAH PLANT SCRUM TASKLETS] }
  let(:human_group_id) { 'fc8e7ac7-be76-4f1b-b481-6221f06b20a8' }
  let(:repair_grants) do
    grants = (audit_keys - ['ASSIGN_ISSUES']).each_with_index.map do |permission, index|
      role_grant(10_600 + index, permission)
    end
    grants + [role_grant(10_532, 'ASSIGN_ISSUES', role: '10003'), grant_response]
  end

  before do
    stub_repair_projects
    jira_get('role/10076', role_response)
    jira_get('role/10003', role_response(id: 10_003, name: 'atlassian-addons-project-access'))
    stub_grants(*repair_grants)
    stub_repair_group(human_group_id, 'jira-project-users', [{ 'accountId' => 'human-account', 'active' => true }])
    stub_repair_group('service-group', 'pah-ticket-managers', [{ 'accountId' => 'service-account', 'active' => true }])
    jira_get('user/groups', [group_response(id: 'service-group', name: 'pah-ticket-managers')],
             params: { accountId: 'service-account' })
    stub_repair_role('PAH', [group_actor('service-group', 'pah-ticket-managers')])
    stub_repair_role('GEN', [])
  end

  def role_grant(id, permission, role: '10076')
    grant_response(id: id, type: 'projectRole', value: role).merge('permission' => permission)
  end

  def human_grant
    grant_response(id: 10_800, type: 'group', value: human_group_id)
  end

  def group_actor(id, name, actor: 1)
    { 'id' => actor, 'type' => 'atlassian-group-role-actor', 'actorGroup' => group_response(id: id, name: name) }
  end

  def stub_repair_group(id, name, members)
    stub_group(id: id, name: name)
    jira_get('group/member', page(members),
             params: { groupId: id, includeInactiveUsers: true, startAt: 0, maxResults: 50 })
  end

  def stub_repair_role(project, actors)
    jira_get("project/#{project}/role/10076", role_response.merge('actors' => actors))
  end

  def stub_repair_projects
    stub_audit_inventory(repair_projects.each_with_index.map { |key, index| audit_project(key, index + 1) })
    repair_projects.each_with_index do |key, index|
      id = %w[PAH GEN].include?(key) ? 10_003 : 20_000 + index
      jira_get("project/#{key}/permissionscheme", { 'id' => id, 'name' => 'GEN software permission scheme' })
      stub_audit_permissions(key, %w[PAH ADMIN].include?(key))
    end
    stub_audit_permissions('GEN', false, 'ASSIGN_ISSUES' => { 'key' => 'ASSIGN_ISSUES', 'havePermission' => true })
  end
end
