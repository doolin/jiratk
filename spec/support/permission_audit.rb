# frozen_string_literal: true

require_relative 'permission_discovery'

RSpec.shared_context 'with a permission audit' do
  include_context 'with permission discovery'

  let(:administrator) { JiraTk::Permissions::Client.new(connection: connection) }
  let(:audit_client) do
    transport = JiraTk::Permissions::Connection.service_account(base_url: audit_gateway, token: 'synthetic-bearer')
    JiraTk::Permissions::Client.new(connection: transport)
  end

  before do
    stub_identity
    stub_identity(base: audit_gateway, authorization: 'Bearer synthetic-bearer', id: 'service-account')
    allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 26, 12))
  end

  def audit_gateway
    'https://api.atlassian.com/ex/jira/00000000-1111-2222-3333-444444444444'
  end

  def audit_keys
    %w[BROWSE_PROJECTS CREATE_ISSUES EDIT_ISSUES TRANSITION_ISSUES ADD_COMMENTS ASSIGN_ISSUES]
  end

  def audit_project(key, id, status: 'live', style: 'classic')
    { 'key' => key, 'id' => id, 'name' => "Project #{key}", 'status' => status, 'style' => style }
  end

  def stub_audit_inventory(projects)
    jira_get('mypermissions', { 'permissions' => { 'ADMINISTER' => { 'havePermission' => true } } },
             params: { permissions: 'ADMINISTER' })
    %w[live archived deleted].each do |status|
      stub_project_page(status, projects.select { |project| project['status'] == status })
    end
  end

  def permission_response(allowed, entries = {})
    { 'permissions' => audit_keys.to_h { |key| [key, { 'key' => key, 'havePermission' => allowed }] }.merge(entries) }
  end

  def stub_audit_permissions(project, allowed, entries = {})
    jira_get('mypermissions', permission_response(allowed, entries),
             base: audit_gateway, authorization: 'Bearer synthetic-bearer', params: permission_query(project))
  end

  def permission_query(project)
    { projectKey: project, permissions: audit_keys.join(',') }
  end
end
