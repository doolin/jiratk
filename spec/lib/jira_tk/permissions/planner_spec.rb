# frozen_string_literal: true

require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::Planner do
  subject(:planner) { described_class.new(administrator: administrator, audit_client: audit_client) }

  include_context 'with a permission repair plan'

  let(:plan) { planner.pah_assign_repair(**repair_options) }
  let(:steps) { plan.to_h['steps'] }
  let(:projected) { plan.to_h['projected_grants'] }
  let(:payloads) do
    [
      { 'permission' => 'ASSIGN_ISSUES', 'holder' => { 'type' => 'projectRole', 'value' => '10076' } },
      { 'permission' => 'ASSIGN_ISSUES', 'holder' => { 'type' => 'group', 'value' => human_group_id } }
    ]
  end

  it 'orders replacement additions and verification before the exact deletion' do
    expect(steps.map { |step| step['action'] }).to eq(
      %w[verify_preconditions add add verify_replacements verify_controls
         verify_preconditions delete verify_projected_grants verify_controls]
    )
  end

  it 'uses role and immutable group IDs with value alone in create payloads' do
    expect(steps[1, 2].map { |step| step['payload'] }).to eq(payloads)
  end

  it 'binds deletion to the scheme and full normalized grant' do
    expect(steps[6]).to eq('action' => 'delete', 'scheme_id' => '10003', 'expected_grant' => {
                             'id' => '10592', 'permission' => 'ASSIGN_ISSUES',
                             'holder' => { 'type' => 'applicationRole', 'id' => nil, 'supported' => true }
                           })
  end

  it 'preserves PAH and unrelated controls while requiring GEN assignment denial', :aggregate_failures do
    controls = plan.to_h['controls']

    expect(controls['after_delete']['PAH'].values).to eq([true] * 6)
    expect(controls['after_delete']['GEN'].values).to eq([false] * 6)
    expect(controls['after_delete']['ADMIN']).to eq(controls['before_delete']['ADMIN'])
  end

  it 'retains every protected and unrelated grant', :aggregate_failures do
    expect(projected.map { |grant| grant['id'] }.compact)
      .to contain_exactly('10532', *%w[10600 10601 10602 10603 10604])
    expect(plan.to_h['protected_grants'].map { |grant| grant['id'] }).to eq(['10532'])
  end

  it 'leaves new grant IDs unknown until a future write and readback' do
    expect(projected.count { |grant| grant['id'].nil? }).to eq(2)
  end

  it 'plans existing replacements as verified no-ops' do
    stub_grants(*repair_grants, role_grant(10_700, 'ASSIGN_ISSUES'), human_grant)

    expect(steps[1, 2].map { |step| step.values_at('action', 'grant_id') }).to eq([%w[noop 10700], %w[noop 10800]])
  end

  %i[post put delete].each do |method|
    it "never sends #{method.to_s.upcase} during planning and revalidation" do
      planner.revalidate(plan)

      expect(a_request(method, %r{/rest/api/3/})).not_to have_been_made
    end
  end

  it 'revalidates the reviewed object despite a later capture time' do
    reviewed = plan
    allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 27))

    expect(planner.revalidate(reviewed)).to equal(reviewed)
  end

  it 'rejects an unrelated grant change instead of silently regenerating scope' do
    reviewed = plan
    stub_grants(*repair_grants, grant_response(id: 10_999, type: 'user', value: 'someone'))

    expect { planner.revalidate(reviewed) }.to raise_error(error_class, /preconditions changed/)
  end

  it 'rejects a changed human replacement population' do
    reviewed = plan
    stub_repair_group(human_group_id, 'jira-project-users', [])

    expect { planner.revalidate(reviewed) }.to raise_error(error_class, /preconditions changed/)
  end

  it 'rejects unreviewed objects' do
    expect { planner.revalidate({}) }.to raise_error(error_class, /Expected a reviewed permission plan/)
  end

  it 'keeps connection details out of inspection' do
    expect(planner.inspect).to eq('#<JiraTk::Permissions::Planner>')
  end

  context 'when the broad grant is already absent' do
    before do
      stub_grants(*repair_grants.reject { |grant| grant['id'] == 10_592 },
                  role_grant(10_700, 'ASSIGN_ISSUES'), human_grant)
      stub_audit_permissions('GEN', false)
    end

    it 'verifies the complete evidence before planning a no-op deletion' do
      expect(steps.values_at(1, 2, 6).map { |step| step['action'] }).to eq(%w[noop noop noop])
    end

    it 'rejects missing replacements despite the absent target' do
      stub_grants(*repair_grants.reject { |grant| grant['id'] == 10_592 })

      expect { plan }.to raise_error(error_class, /Absent broad grant lacks verified replacements/)
    end

    it 'rejects unresolved negative controls despite the absent target' do
      stub_audit_permissions('GEN', false, 'ASSIGN_ISSUES' => { 'key' => 'ASSIGN_ISSUES', 'havePermission' => true })

      expect { plan }.to raise_error(error_class, /unresolved negative controls/)
    end
  end
end
