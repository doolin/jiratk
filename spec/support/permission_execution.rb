# frozen_string_literal: true

require_relative 'permission_plan'

RSpec.shared_context 'with permission execution' do
  include_context 'with a permission repair plan'

  let(:plan) do
    JiraTk::Permissions::Planner.new(administrator: administrator, audit_client: audit_client)
                                .pah_assign_repair(**repair_options)
  end
  let(:world) do
    { grants: JSON.parse(JSON.generate(repair_grants)), assign: true, captures: 0, events: [], sleeps: [] }
  end

  before do
    plan
    stub_execution_reads
    stub_execution_writes
  end

  def permission_url
    "#{origin}/rest/api/3/permissionscheme/10003/permission"
  end

  def execution_options
    { administrator_connection: connection, audit_client: audit_client, sleeper: ->(delay) { world[:sleeps] << delay } }
  end

  def stub_execution_reads
    stub_execution_identity
    stub_request(:get, permission_url).with(basic_auth: %w[synthetic-admin synthetic-secret])
                                      .to_return do
      {
        status: 200, body: JSON.generate('permissions' => world[:grants])
      }
    end
    stub_execution_controls
  end

  def stub_execution_identity
    stub_request(:get,
                 "#{origin}/rest/api/3/myself").with(basic_auth: %w[synthetic-admin synthetic-secret]).to_return do
      world[:captures] += 1
      world[:events] << :capture
      world[:on_capture]&.call(world[:captures])
      { status: 200, body: JSON.generate('accountId' => 'admin-account', 'active' => true) }
    end
  end

  def stub_execution_controls
    stub_request(:get, "#{audit_gateway}/rest/api/3/mypermissions")
      .with(query: permission_query('GEN'), headers: { 'Authorization' => 'Bearer synthetic-bearer' }).to_return do
        controls = permission_response(false, 'ASSIGN_ISSUES' => { 'key' => 'ASSIGN_ISSUES',
                                                                   'havePermission' => world[:assign] })
        { status: 200, body: JSON.generate(controls) }
      end
  end

  def stub_execution_writes
    [role_grant(10_700, 'ASSIGN_ISSUES'), human_grant].each do |grant|
      stub_execution_post(grant)
    end
    stub_execution_delete
  end

  def stub_execution_post(grant)
    payload = grant.slice('permission', 'holder')
    stub_request(:post, permission_url).with(body: payload,
                                             basic_auth: %w[
                                               synthetic-admin synthetic-secret
                                             ]).to_return do
      world[:events] << grant['id']
      world[:on_post] ? world[:on_post].call(grant) : accept_grant(grant)
    end
  end

  def stub_execution_delete
    stub_request(:delete, "#{permission_url}/10592").with(basic_auth: %w[synthetic-admin synthetic-secret]).to_return do
      world[:events] << :delete
      world[:on_delete] ? world[:on_delete].call : accept_deletion
    end
  end

  def accept_grant(grant)
    world[:grants] << grant
    { status: 201, body: JSON.generate(grant) }
  end

  def accept_deletion
    world[:grants].reject! { |grant| grant['id'] == 10_592 }
    world[:assign] = false
    { status: 204, body: '' }
  end

  def writes
    world[:events].reject { |event| event == :capture }
  end
end
