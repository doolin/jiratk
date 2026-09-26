# frozen_string_literal: true

RSpec.shared_context 'with permission discovery' do
  let(:origin) { 'https://permissions.example.test' }
  let(:connection) { JiraTk::Permissions::Connection.administrator }
  let(:error_class) { JiraTk::Permissions::Error }

  before do
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_URL', nil).and_return(origin)
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_ID', nil).and_return('synthetic-admin')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_API', nil).and_return('synthetic-secret')
  end

  def jira_get(path, body, params: {}, base: origin,
               authorization: 'Basic c3ludGhldGljLWFkbWluOnN5bnRoZXRpYy1zZWNyZXQ=')
    stub_request(:get, "#{base}/rest/api/3/#{path}")
      .with(query: params, headers: { 'Authorization' => authorization })
      .to_return(status: 200, body: JSON.generate(body))
  end

  def page(values, offset: 0, total: values.length, last: true)
    { 'startAt' => offset, 'maxResults' => 50, 'total' => total, 'isLast' => last, 'values' => values }
  end

  def group_response(id: 'group-1', name: 'Humans')
    { 'groupId' => id, 'name' => name }
  end

  def role_response(id: 10_076, name: 'Ticket Manager')
    { 'id' => id, 'name' => name }
  end

  def grant_response(id: 10_592, type: 'applicationRole', **fields)
    { 'id' => id, 'permission' => 'ASSIGN_ISSUES', 'holder' => { 'type' => type }.merge(fields.transform_keys(&:to_s)) }
  end

  def stub_group(id: 'group-1', name: 'Humans')
    jira_get('group/bulk', page([group_response(id: id, name: name)]),
             params: { groupId: id, startAt: 0, maxResults: 50 })
  end

  def stub_identity(base: origin, authorization: 'Basic c3ludGhldGljLWFkbWluOnN5bnRoZXRpYy1zZWNyZXQ=',
                    id: 'admin-account', site: origin)
    jira_get('myself', { 'accountId' => id, 'active' => true, 'emailAddress' => 'omit@example.test' },
             base: base, authorization: authorization)
    jira_get('serverInfo', { 'baseUrl' => site }, base: base, authorization: authorization)
  end

  def stub_project_page(status, projects, offset: 0, total: projects.length, last: true)
    jira_get('project/search', page(projects, offset: offset, total: total, last: last),
             params: { status: status, orderBy: 'key', startAt: offset, maxResults: 50 })
  end

  def stub_grants(*grants)
    jira_get('permissionscheme/10003/permission', { 'permissions' => grants })
  end

  def stub_group_members(users, offset: 0, total: users.length, last: true)
    jira_get('group/member', page(users, offset: offset, total: total, last: last),
             params: { groupId: 'group-1', includeInactiveUsers: true, startAt: offset, maxResults: 50 })
  end

  def stub_role_actors(*actors)
    jira_get('project/PAH/role/10076', role_response.merge('actors' => actors))
  end
end
