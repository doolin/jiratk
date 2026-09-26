# frozen_string_literal: true

require_relative '../../../support/permission_execution'

RSpec.describe JiraTk::Permissions::Executor do
  subject(:executor) { described_class.new(**execution_options) }

  include_context 'with permission execution'

  def apply_result
    executor.execute(plan, apply: true).to_h
  end

  def expect_stopped_before_writes
    expect(apply_result).to include('status' => 'failed', 'exit_status' => 2, 'write_attempts' => [])
    expect(writes).to be_empty
  end

  it 'rejects an unrelated addition in the reviewed scheme', :aggregate_failures do
    world[:grants] << grant_response(id: 10_999, type: 'user', value: 'other-account')
    expect_stopped_before_writes
  end

  [10_532, 10_604, 10_592].each do |id|
    it 'rejects removal of a protected grant, other PAH permission, or premature broad removal', :aggregate_failures do
      world[:grants].reject! { |grant| grant['id'] == id }
      expect_stopped_before_writes
    end
  end

  it 'rejects an equivalent broad grant under a different ID', :aggregate_failures do
    world[:grants].find { |grant| grant['id'] == 10_592 }['id'] = 10_999
    expect_stopped_before_writes
  end

  it 'preserves the distinction between absent and empty application-role identities', :aggregate_failures do
    world[:grants].find { |grant| grant['id'] == 10_592 }['holder']['value'] = ''
    expect_stopped_before_writes
  end

  it 'rejects an out-of-order partial repair', :aggregate_failures do
    world[:grants] << human_grant
    expect_stopped_before_writes
  end

  it 'rejects duplicate candidate replacements', :aggregate_failures do
    world[:grants].push(role_grant(10_700, 'ASSIGN_ISSUES'), role_grant(10_701, 'ASSIGN_ISSUES'))
    expect_stopped_before_writes
  end

  it 'rejects site identity drift', :aggregate_failures do
    stub_identity(base: audit_gateway, authorization: 'Bearer synthetic-bearer', id: 'service-account',
                  site: 'https://another.example.test')
    expect_stopped_before_writes
  end

  it 'rejects missing administrator permissions', :aggregate_failures do
    jira_get('mypermissions', { 'permissions' => { 'ADMINISTER' => { 'havePermission' => false } } },
             params: { permissions: 'ADMINISTER' })
    expect_stopped_before_writes
  end

  it 'rejects changed scheme associations', :aggregate_failures do
    jira_get('project/GEN/permissionscheme', { 'id' => 20_000, 'name' => 'Another scheme' })
    expect_stopped_before_writes
  end

  it 'rejects changed role membership', :aggregate_failures do
    stub_repair_role('GEN', [group_actor('service-group', 'pah-ticket-managers')])
    expect_stopped_before_writes
  end

  [false, nil].each do |permission|
    it 'rejects denied or unknown PAH comment access', :aggregate_failures do
      stub_audit_permissions('PAH', true, 'ADD_COMMENTS' => { 'key' => 'ADD_COMMENTS', 'havePermission' => permission })
      expect_stopped_before_writes
    end
  end

  it 'rejects unexpected access in an unrelated project', :aggregate_failures do
    stub_audit_permissions('BST', true)
    expect_stopped_before_writes
  end

  [[2, []], [4, [10_700]], [6, [10_700, 10_800]]].each do |capture, expected_writes|
    it 'rechecks group population immediately before each write', :aggregate_failures do
      world[:on_capture] = ->(count) { stub_repair_group(human_group_id, 'jira-project-users', []) if count == capture }
      expect(apply_result['status']).to eq('failed')
      expect(writes).to eq(expected_writes)
    end
  end

  it 'rejects changed replacement IDs before deletion', :aggregate_failures do
    world[:on_capture] = ->(count) { change_role_id if count == 6 }
    expect(apply_result).to include('status' => 'failed', 'exit_status' => 3)
    expect(writes).to eq([10_700, 10_800])
  end

  def change_role_id
    world[:grants].find { |grant| grant['id'] == 10_700 }['id'] = 10_701
  end

  it 'stops immediately if protected grants disappear after a write', :aggregate_failures do
    world[:on_capture] = ->(count) { world[:grants].reject! { |grant| grant['id'] == 10_532 } if count == 3 }
    expect(apply_result['failure']).to eq('category' => 'state_changed')
    expect(writes).to eq([10_700])
    expect(world[:sleeps]).to be_empty
  end

  it 'reports post-deletion PAH regression without rolling back', :aggregate_failures do
    world[:on_capture] = ->(count) { stub_audit_permissions('PAH', false) if count == 7 }
    expect(apply_result).to include('status' => 'failed', 'exit_status' => 3)
    expect(writes).to eq([10_700, 10_800, :delete])
    expect(world[:grants].map { |grant| grant['id'] }).to include(10_700, 10_800)
  end
end
