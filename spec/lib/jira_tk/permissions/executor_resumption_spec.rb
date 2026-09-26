# frozen_string_literal: true

require_relative '../../../support/permission_execution'

RSpec.describe JiraTk::Permissions::Executor do
  subject(:executor) { described_class.new(**execution_options) }

  include_context 'with permission execution'

  it 'resumes after the first verified replacement', :aggregate_failures do
    world[:grants] << role_grant(10_700, 'ASSIGN_ISSUES')
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
    expect(writes).to eq([10_800, :delete])
  end

  it 'resumes after both verified replacements', :aggregate_failures do
    world[:grants].push(role_grant(10_700, 'ASSIGN_ISSUES'), human_grant)
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
    expect(writes).to eq([:delete])
  end

  it 'recognizes an already-complete repair', :aggregate_failures do
    world[:grants].push(role_grant(10_700, 'ASSIGN_ISSUES'), human_grant)
    accept_deletion
    expect(executor.execute(plan, apply: true).to_h).to include('status' => 'unchanged', 'write_attempts' => [])
    expect(writes).to be_empty
  end

  it 'does not treat absent grants as success with unresolved final controls', :aggregate_failures do
    world[:grants].push(role_grant(10_700, 'ASSIGN_ISSUES'), human_grant)
    world[:grants].reject! { |grant| grant['id'] == 10_592 }
    expect(executor.execute(plan, apply: true).to_h).to include('status' => 'failed', 'exit_status' => 2)
    expect(writes).to be_empty
  end

  context 'with originally existing replacements' do
    let(:repair_grants) { super() + [role_grant(10_700, 'ASSIGN_ISSUES'), human_grant] }

    it 'verifies original IDs and only deletes the reviewed broad grant', :aggregate_failures do
      result = executor.execute(plan, apply: true).to_h
      expect(result['steps'].map { |step| step['action'] }).to eq(%w[noop noop delete])
      expect(writes).to eq([:delete])
    end

    it 'refuses to substitute a newly assigned ID for an original grant', :aggregate_failures do
      world[:grants].find { |grant| grant['id'] == 10_700 }['id'] = 10_701
      expect(executor.execute(plan, apply: true).to_h['status']).to eq('failed')
      expect(writes).to be_empty
    end
  end

  context 'with only the human replacement originally present' do
    let(:repair_grants) { super() + [human_grant] }

    it 'adds only the missing role before deleting', :aggregate_failures do
      expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
      expect(writes).to eq([10_700, :delete])
    end
  end

  context 'with a duplicate unrelated grant in the reviewed baseline' do
    let(:repair_grants) do
      super() + [grant_response(id: 11_001, type: 'user', value: 'other'),
                 grant_response(id: 11_002, type: 'user', value: 'other')]
    end

    it 'preserves both exact original IDs', :aggregate_failures do
      expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
      expect(world[:grants].map { |grant| grant['id'] }).to include(11_001, 11_002)
    end
  end

  context 'with an already-complete reviewed baseline' do
    let(:repair_grants) do
      super().reject { |grant| grant['id'] == 10_592 } + [role_grant(10_700, 'ASSIGN_ISSUES'), human_grant]
    end
    let(:plan) do
      stub_audit_permissions('GEN', false)
      super()
    end

    it 'verifies all original no-ops', :aggregate_failures do
      world[:assign] = false
      result = executor.execute(plan, apply: true).to_h
      expect(result).to include('status' => 'unchanged', 'write_attempts' => [])
      expect(result['steps'].map { |step| step['status'] }).to eq(%w[completed completed completed])
    end
  end
end
