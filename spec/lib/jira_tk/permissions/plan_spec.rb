# frozen_string_literal: true

require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::Plan do
  subject(:plan) { planner.pah_assign_repair(**repair_options) }

  include_context 'with a permission repair plan'

  let(:planner) { JiraTk::Permissions::Planner.new(administrator: administrator, audit_client: audit_client) }
  let(:document) { plan.to_h }

  def load_document(data)
    described_class.load(JSON.generate(data))
  end

  def change(data, path, value)
    parent = path[0...-1].reduce(data) { |node, key| node.fetch(key) }
    parent[path.last] = value
    data['digest'] = JiraTk::Permissions::PlanData.digest(data.except('digest'))
  end

  it 'round-trips a reviewed plan without changing its evidence or steps' do
    expect(described_class.load(plan.dump).dump).to eq(plan.dump)
  end

  it 'keeps serialization stable when Jira returns grants in a different order' do
    reviewed = plan.dump
    stub_grants(*repair_grants.reverse)

    expect(planner.pah_assign_repair(**repair_options).dump).to eq(reviewed)
  end

  it 'records the protected and broad grants through the addition checkpoint' do
    expect(document['after_additions'].map { |grant| grant['id'] }.compact).to include('10532', '10592')
  end

  it 'does not let returned data alter the reviewed plan', :aggregate_failures do
    document['request']['account_id'] = 'different'
    document['evidence']['audit']['projects'].first['permissions']['EDIT_ISSUES'] = false

    expect(plan.request['account_id']).to eq('service-account')
    expect(plan.preconditions['audit']['projects'].first['permissions']['EDIT_ISSUES']).to be(true)
  end

  it 'copies constructor input before retaining it' do
    saved = described_class.new(request: document['request'], evidence: document['evidence'])
    document['evidence']['groups'].clear

    expect(saved.to_h['evidence']['groups'].length).to eq(2)
  end

  it 'excludes unrequested API metadata and configuration from saved evidence' do
    stub_repair_group(human_group_id, 'jira-project-users',
                      [{ 'accountId' => 'human-account', 'active' => true, 'emailAddress' => 'synthetic-secret' }])

    expect(plan.dump).not_to include('synthetic', 'Authorization', 'emailAddress', 'baseUrl', origin)
  end

  it 'allowlists injected snapshot metadata before building a new plan' do
    document['evidence']['token'] = 'synthetic-secret'
    saved = described_class.new(request: document['request'], evidence: document['evidence'])

    expect(saved.dump).not_to include('synthetic-secret', 'token')
  end

  it 'limits inspection to the class and content digest' do
    expect(plan.inspect).to match(/\A#<JiraTk::Permissions::Plan digest=[0-9a-f]{64}>\z/)
  end

  it 'detects a valid timestamp edit made without updating the digest' do
    document['created_at'] = '2026-09-27T12:00:00Z'

    expect { load_document(document) }.to raise_error(error_class, /content or digest differs/)
  end

  it 'rejects reordered steps even when the editor recomputes the digest' do
    change(document, ['steps'], document['steps'].reverse)

    expect { load_document(document) }.to raise_error(error_class, /content or digest differs/)
  end

  it 'rejects a protected deletion substituted into the saved steps' do
    change(document, ['steps', 6, 'expected_grant'], document['request']['protected_grant'])

    expect { load_document(document) }.to raise_error(error_class, /content or digest differs/)
  end

  ['"version": 1', '"account_id": "service-account"'].each do |field|
    it 'rejects duplicate JSON fields at the document and nested request boundaries' do
      ambiguous = plan.dump.sub(field, "#{field}, #{field}")

      expect { described_class.load(ambiguous) }.to raise_error(error_class, 'Saved permission plan is invalid')
    end
  end

  it 'rejects an unknown field even with a recomputed digest' do
    change(document, ['token'], 'synthetic-secret')

    expect { load_document(document) }.to raise_error(error_class, /content or digest differs/)
  end

  [nil, '1', 2].each do |version|
    it 'rejects an unsupported schema version' do
      document['version'] = version

      expect { load_document(document) }.to raise_error(error_class, /Unsupported permission plan version/)
    end
  end

  [
    [%w[evidence audit identity site_id], 'wrong'],
    [%w[evidence audit identity active], false],
    [%w[evidence audit identity id], 'another-account'],
    [%w[evidence audit timestamp], 'not a timestamp'],
    [['evidence', 'audit', 'projects', 0, 'permissions', 'EDIT_ISSUES'], nil],
    [['evidence', 'inventory', 0, 'status'], 'archived'],
    [['evidence', 'inventory', 0, 'id'], '999'],
    [['evidence', 'project_roles', 1, 'project'], 'WRONG'],
    [['evidence', 'project_roles', 1, 'actors', 0, 'type'], 'unsupported'],
    [['evidence', 'scheme', 'grants', 1, 'holder', 'id'], false],
    [['evidence', 'scheme', 'grants', 2, 'holder', 'name'], 'Different role']
  ].each do |path, value|
    it "rejects invalid saved evidence at #{path.join('.')}" do
      change(document, path, value)

      expect { load_document(document) }.to raise_error(error_class)
    end
  end

  it 'rejects a missing required baseline project' do
    document['evidence']['inventory'].shift

    expect { load_document(document) }.to raise_error(error_class, /complete supported project coverage/)
  end

  it 'rejects a group inventory that omits relevant membership evidence' do
    document['evidence']['groups'].shift

    expect { load_document(document) }.to raise_error(error_class, /Relevant group inventory differs/)
  end

  it 'rejects malformed request objects without exposing their contents' do
    document['request']['service_group'] = 'synthetic-secret'

    expect { load_document(document) }.to raise_error(error_class, 'Expected a Jira object')
  end

  it 'sanitizes missing snapshot fields', :aggregate_failures do
    document['evidence'].delete('audit')

    expect { load_document(document) }.to raise_error(error_class, 'Plan data is incomplete or invalid') do |error|
      expect(error.cause).to be_nil
    end
  end

  it 'sanitizes missing document fields' do
    document.delete('created_at')

    expect { load_document(document) }.to raise_error(error_class, 'Saved permission plan is invalid')
  end

  it 'sanitizes malformed JSON and drops its original exception', :aggregate_failures do
    expect { described_class.load('not JSON: synthetic-secret') }
      .to raise_error(error_class, 'Saved permission plan is invalid') do |error|
        expect(error.cause).to be_nil
      end
  end

  ['null', '[]', '{}'].each do |json|
    it 'rejects a JSON document without a supported plan envelope' do
      expect { described_class.load(json) }.to raise_error(error_class)
    end
  end
end
