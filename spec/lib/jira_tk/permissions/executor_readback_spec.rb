# frozen_string_literal: true

require_relative '../../../support/permission_execution'

RSpec.describe JiraTk::Permissions::Executor do
  subject(:executor) { described_class.new(**execution_options) }

  include_context 'with permission execution'

  def delay_first_readback(count)
    world[:grants].reject! { |grant| grant['id'] == 10_700 } if count == 3
    world[:grants] << role_grant(10_700, 'ASSIGN_ISSUES') if count == 4
  end

  it 'bounds retries while waiting for grant visibility', :aggregate_failures do
    world[:on_capture] = method(:delay_first_readback)
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
    expect(world[:sleeps]).to eq([1])
  end

  it 'does not forget uncertainty across a blocked resume attempt', :aggregate_failures do
    world[:on_post] = ->(_grant) { raise Timeout::Error }
    first = executor.execute(plan, apply: true)
    blocked = executor.execute(plan, apply: true, previous: first)
    expect(executor.execute(plan, apply: true, previous: blocked).to_h['status']).to eq('failed')
    expect(writes).to eq([10_700])
  end

  it 'can transfer resumption evidence to another executor', :aggregate_failures do
    world[:on_post] = ->(grant) { grant['id'] == 10_800 ? { status: 403 } : accept_grant(grant) }
    previous = executor.execute(plan, apply: true)
    world[:on_post] = nil
    expect(described_class.new(**execution_options).execute(plan, apply: true, previous: previous).to_h['status'])
      .to eq('applied')
  end

  it 'automatically retains unresolved writes within the same executor', :aggregate_failures do
    world[:on_post] = ->(_grant) { raise Timeout::Error }
    executor.execute(plan, apply: true)
    expect(executor.execute(plan, apply: true).to_h['failure']).to eq('category' => 'unresolved_write')
    expect(writes).to eq([10_700])
  end

  it 'treats an HTTP timeout as uncertain rather than a verified rejection', :aggregate_failures do
    world[:on_post] = ->(_grant) { { status: 408 } }
    previous = executor.execute(plan, apply: true)
    expect(previous.to_h['steps'].first['status']).to eq('uncertain')
    expect(executor.execute(plan, apply: true).to_h['failure']).to eq('category' => 'unresolved_write')
    expect(writes).to eq([10_700])
  end

  it 'does not replay a previously verified replacement that later disappears', :aggregate_failures do
    world[:on_post] = ->(grant) { grant['id'] == 10_800 ? { status: 403 } : accept_grant(grant) }
    executor.execute(plan, apply: true)
    world[:grants].reject! { |grant| grant['id'] == 10_700 }
    expect(executor.execute(plan, apply: true).to_h['failure']).to eq('category' => 'state_changed')
    expect(writes).to eq([10_700, 10_800])
  end

  it 'permits a new explicit attempt after a verified rejection', :aggregate_failures do
    world[:on_post] = ->(_grant) { { status: 403 } }
    previous = executor.execute(plan, apply: true)
    world[:on_post] = nil
    expect(executor.execute(plan, apply: true, previous: previous).to_h['status']).to eq('applied')
    expect(writes).to eq([10_700, 10_700, 10_800, :delete])
  end

  context 'with a previously acknowledged but unobserved creation' do
    before do
      world[:on_post] = ->(grant) { { status: 201, body: JSON.generate(grant) } }
    end

    it 'retains the acknowledged ID during resumption', :aggregate_failures do
      previous = executor.execute(plan, apply: true)
      world[:grants] << role_grant(10_701, 'ASSIGN_ISSUES')
      expect(executor.execute(plan, apply: true, previous: previous).to_h['status']).to eq('failed')
      expect(writes).to eq([10_700])
    end
  end

  it 'waits for expected negative controls to propagate after deletion', :aggregate_failures do
    world[:on_capture] = ->(count) { world[:assign] = count == 7 if count >= 7 }
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('applied')
    expect(world[:sleeps]).to eq([1])
    expect(writes).to eq([10_700, 10_800, :delete])
  end

  it 'reports persistent GEN assignment access instead of claiming success', :aggregate_failures do
    world[:on_capture] = ->(count) { world[:assign] = true if count >= 7 }
    result = executor.execute(plan, apply: true).to_h
    expect(result['failure']).to eq('category' => 'verification_pending')
    expect(result['last_observation']['controls_verified']).to be(false)
    expect(world[:sleeps]).to eq([1, 1])
  end

  it 'reports exhausted grant readback without replaying the POST', :aggregate_failures do
    world[:on_capture] = ->(count) { world[:grants].reject! { |grant| grant['id'] == 10_700 } if count >= 3 }
    result = executor.execute(plan, apply: true).to_h
    expect(result['steps'].first['status']).to eq('uncertain')
    expect(result['failure']).to eq('category' => 'verification_pending')
    expect(writes).to eq([10_700])
  end

  it 'blocks resumption until a previous uncertain write is observed', :aggregate_failures do
    world[:on_post] = ->(_grant) { raise Timeout::Error }
    previous = executor.execute(plan, apply: true)
    result = executor.execute(plan, apply: true, previous: previous).to_h
    expect(result['failure']).to eq('category' => 'unresolved_write')
    expect(writes).to eq([10_700])
  end

  it 'resumes an uncertain write once its exact replacement is visible', :aggregate_failures do
    world[:on_post] = ->(_grant) { raise Timeout::Error }
    previous = executor.execute(plan, apply: true)
    world[:on_post] = nil
    world[:grants] << role_grant(10_700, 'ASSIGN_ISSUES')
    expect(executor.execute(plan, apply: true, previous: previous).to_h['status']).to eq('applied')
  end

  it 'rejects an invalid previous result', :aggregate_failures do
    result = executor.execute(plan, apply: true, previous: {}).to_h
    expect(result['failure']).to eq('category' => 'precondition_failed')
    expect(writes).to be_empty
  end

  it 'rejects a previous result for a different reviewed plan', :aggregate_failures do
    previous = executor.execute(plan)
    newer = JiraTk::Permissions::Plan.new(request: plan.request, evidence: plan.to_h['evidence'],
                                          created_at: '2026-09-27T12:00:00Z')
    expect(executor.execute(newer, apply: true, previous: previous).to_h['status']).to eq('failed')
    expect(writes).to be_empty
  end

  it 'stops on new progress by another writer within an active run', :aggregate_failures do
    world[:on_capture] = ->(count) { world[:grants] << role_grant(10_700, 'ASSIGN_ISSUES') if count == 2 }
    expect(executor.execute(plan, apply: true).to_h['failure']).to eq('category' => 'state_changed')
    expect(writes).to be_empty
  end
end
