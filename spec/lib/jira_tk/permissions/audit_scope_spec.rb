# frozen_string_literal: true

RSpec.describe JiraTk::Permissions::AuditScope do
  subject(:scope) { described_class.new(required: %w[GEN], positive: 'GEN') }

  let(:project) { { 'id' => '1', 'key' => 'GEN', 'status' => 'live', 'style' => 'classic' } }

  it 'supports a different positive project without adding PAH implicitly' do
    expect(scope.reconcile([project]).first).to include('key' => 'GEN', 'expected' => true, 'coverage' => 'audited')
  end

  it 'rejects unknown discovery states' do
    expect { scope.reconcile([project.merge('status' => 'unexpected')]) }
      .to raise_error(JiraTk::Permissions::Error, 'Unsupported project status')
  end

  it 'rejects duplicate projects instead of overwriting an inventory row' do
    expect do
      scope.reconcile([project, project])
    end.to raise_error(JiraTk::Permissions::Error, /Duplicate Jira identities/)
  end

  [{ 'id' => nil }, { 'key' => '../GEN' }, { 'style' => nil }].each do |invalid|
    it 'validates the inventory supplied by an injected discovery client' do
      expect { scope.reconcile([project.merge(invalid)]) }.to raise_error(JiraTk::Permissions::Error)
    end
  end
end
