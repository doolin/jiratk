# frozen_string_literal: true

require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::PlanSnapshot do
  subject(:snapshot) { described_class.new(administrator: administrator, audit_client: audit_client) }

  include_context 'with a permission repair plan'

  it 'does not expose the injected connections during inspection' do
    expect(snapshot.inspect).to eq('#<JiraTk::Permissions::PlanSnapshot>')
  end
end
