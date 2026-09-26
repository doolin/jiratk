# frozen_string_literal: true

require_relative '../../../support/permission_execution'

RSpec.describe JiraTk::Permissions::Executor do
  subject(:executor) { described_class.new(**execution_options) }

  include_context 'with permission execution'

  def step_statuses(result)
    result.to_h['steps'].map { |step| step['status'] }
  end

  def accept_then_timeout(grant)
    accept_grant(grant)
    raise Timeout::Error, 'private transport details'
  end

  def delete_then_timeout
    accept_deletion
    raise IOError, 'private transport details'
  end

  it 'reports a rejected second addition and preserves the first', :aggregate_failures do
    world[:on_post] = ->(grant) { grant['id'] == 10_800 ? { status: 403, body: 'private' } : accept_grant(grant) }
    result = executor.execute(plan, apply: true)
    expect(step_statuses(result)).to eq(%w[completed failed pending])
    expect(result.to_h).to include('status' => 'failed', 'exit_status' => 3)
    expect(writes).to eq([10_700, 10_800])
  end

  it 'stops after an uncertain POST even when readback proves it completed', :aggregate_failures do
    world[:on_post] = method(:accept_then_timeout)
    result = executor.execute(plan, apply: true)
    expect(step_statuses(result)).to eq(%w[completed pending pending])
    expect(result.dump).not_to include('private transport details', 'synthetic')
    expect(writes).to eq([10_700])
  end

  it 'reports an unobserved timeout as uncertain without replaying', :aggregate_failures do
    world[:on_post] = ->(_grant) { raise Timeout::Error, 'private transport details' }
    result = executor.execute(plan, apply: true)
    expect(step_statuses(result)).to eq(%w[uncertain pending pending])
    expect(writes).to eq([10_700])
    expect(world[:sleeps]).to eq([1, 1])
  end

  it 'reconciles a malformed successful POST response without continuing', :aggregate_failures do
    world[:on_post] = ->(grant) { accept_grant(grant).merge(body: 'private invalid JSON') }
    result = executor.execute(plan, apply: true)
    expect(result.to_h['failure']).to include('category' => 'invalid_write_response', 'verification' => nil)
    expect(step_statuses(result)).to eq(%w[completed pending pending])
    expect(writes).to eq([10_700])
  end

  [[], {},
   { 'id' => 10_700, 'permission' => 'EDIT_ISSUES', 'holder' => { 'type' => 'projectRole', 'value' => '10076' } },
   { 'id' => 10_532, 'permission' => 'ASSIGN_ISSUES',
     'holder' => { 'type' => 'projectRole', 'value' => '10076' } }].each do |body|
    it 'rejects malformed or conflicting creation evidence', :aggregate_failures do
      world[:on_post] = ->(grant) { accept_grant(grant).merge(body: JSON.generate(body)) }
      expect(executor.execute(plan, apply: true).to_h['failure']).to include('category' => 'invalid_write_response')
      expect(writes).to eq([10_700])
    end
  end

  it 'requires readback IDs to agree with the creation acknowledgement', :aggregate_failures do
    world[:on_post] = ->(grant) { accept_grant(grant.merge('id' => 10_701)).merge(body: JSON.generate(grant)) }
    result = executor.execute(plan, apply: true)
    expect(result.to_h['failure']).to eq('category' => 'state_changed')
    expect(step_statuses(result)).to eq(%w[uncertain pending pending])
    expect(writes).to eq([10_700])
  end

  [200, 302, 400, 401, 403, 404, 429, 500].each do |status|
    it "stops after POST HTTP #{status}", :aggregate_failures do
      world[:on_post] = ->(_grant) { { status: status, body: 'private response' } }
      result = executor.execute(plan, apply: true)
      expect(result.to_h).to include('status' => 'failed', 'exit_status' => 3)
      expect(writes).to eq([10_700])
      expect(result.dump).not_to include('private response')
    end

    it "does not accept DELETE HTTP #{status} as proof of absence", :aggregate_failures do
      world[:on_delete] = -> { { status: status, body: 'private response' } }
      result = executor.execute(plan, apply: true)
      expect(result.to_h).to include('status' => 'failed', 'exit_status' => 3)
      expect(writes).to eq([10_700, 10_800, :delete])
      expect(world[:grants].map { |grant| grant['id'] }).to include(10_592)
    end
  end

  it 'reconciles an uncertain completed deletion using full evidence', :aggregate_failures do
    world[:on_delete] = method(:delete_then_timeout)
    result = executor.execute(plan, apply: true)
    expect(result.to_h['status']).to eq('failed')
    expect(step_statuses(result)).to eq(%w[completed completed completed])
    expect(executor.execute(plan, apply: true, previous: result).to_h['status']).to eq('unchanged')
  end

  it 'records verified absence after a 404 but still reports the unexpected response', :aggregate_failures do
    world[:on_delete] = -> { accept_deletion.merge(status: 404) }
    result = executor.execute(plan, apply: true)
    expect(result.to_h['failure']).to include('http_status' => 404, 'verification' => nil)
    expect(step_statuses(result)).to eq(%w[completed completed completed])
  end

  it 'does not follow grant creation redirects', :aggregate_failures do
    world[:on_post] = ->(_grant) { { status: 307, headers: { location: 'https://untrusted.test/' } } }
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('failed')
    expect(WebMock).not_to have_requested(:post, 'https://untrusted.test/')
  end

  it 'does not follow grant deletion redirects', :aggregate_failures do
    world[:on_delete] = -> { { status: 307, headers: { location: 'https://untrusted.test/' } } }
    expect(executor.execute(plan, apply: true).to_h['status']).to eq('failed')
    expect(WebMock).not_to have_requested(:delete, 'https://untrusted.test/')
  end
end
