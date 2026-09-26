# frozen_string_literal: true

require_relative '../../../support/permission_execution'

RSpec.describe JiraTk::Permissions::Executor do
  subject(:executor) { described_class.new(**execution_options) }

  include_context 'with permission execution'

  it 'previews the remaining operations by default', :aggregate_failures do
    result = executor.execute(plan).to_h
    expect(result).to include('status' => 'dry-run', 'exit_status' => 0, 'write_attempts' => [])
    expect(result['steps'].map { |step| step['status'] }).to eq(%w[pending pending pending])
    expect(writes).to be_empty
  end

  [nil, false, 'true', 1].each do |apply|
    it 'requires Boolean true for writes', :aggregate_failures do
      expect(executor.execute(plan, apply: apply).to_h['status']).to eq('dry-run')
      expect(writes).to be_empty
    end
  end

  it 'rechecks the complete snapshot before every serial write' do
    executor.execute(plan, apply: true)
    expect(world[:events]).to eq([:capture, :capture, 10_700, :capture, :capture, 10_800,
                                  :capture, :capture, :delete, :capture])
  end

  it 'verifies every step and the final matrix', :aggregate_failures do
    result = executor.execute(plan, apply: true).to_h
    expect(result).to include('status' => 'applied', 'exit_status' => 0, 'write_attempts' => [2, 3, 7])
    expect(result['steps'].map { |step| step['status'] }).to eq(%w[completed completed completed])
    expect(result['last_observation']).to include('prefix' => 3, 'controls_verified' => true)
  end

  it 'preserves protected and unrelated grants exactly' do
    executor.execute(plan, apply: true)
    expected = repair_grants.reject do |grant|
      grant['id'] == 10_592
    end + [role_grant(10_700, 'ASSIGN_ISSUES'), human_grant]
    expect(world[:grants]).to eq(expected)
  end

  it 'makes a complete repeat a verified no-op', :aggregate_failures do
    executor.execute(plan, apply: true)
    result = executor.execute(plan, apply: true).to_h
    expect(result).to include('status' => 'unchanged', 'write_attempts' => [])
    expect(writes).to eq([10_700, 10_800, :delete])
  end

  it 'returns independent credential-free evidence', :aggregate_failures do
    result = executor.execute(plan)
    result.to_h['steps'].clear
    expect(JSON.parse(result.dump)['steps'].length).to eq(3)
    expect(result.dump).not_to include('synthetic', origin, 'authorization', 'password')
  end

  it 'does not expose connections or credentials in inspection' do
    expect(executor.inspect).to eq('#<JiraTk::Permissions::Executor>')
  end

  it 'rejects objects that are not reviewed plans', :aggregate_failures do
    expect { executor.execute(plan.to_h, apply: true) }.to raise_error(error_class, /reviewed permission plan/)
    expect(writes).to be_empty
  end

  it 'keeps raw permission writers private', :aggregate_failures do
    expect(connection).not_to respond_to(:create_permission)
    expect(connection).not_to respond_to(:delete_permission)
  end

  it 'keeps callback-based construction out of the public API' do
    expect { JiraTk::Permissions::ExecutionRun }.to raise_error(NameError, /private constant/)
  end

  it 'emits no raw transport output' do
    expect { executor.execute(plan, apply: true) }.not_to output.to_stdout
  end
end
