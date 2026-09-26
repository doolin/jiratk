# frozen_string_literal: true

require_relative '../../../support/permission_execution'

module JiraTk
  module Permissions
    RSpec.describe ExecutionRun do
      subject(:run) do
        described_class.new(plan: plan, snapshot: snapshot, mutations: {}, holder: nil,
                            readback: JiraTk::Permissions::Readback.new)
      end

      include_context 'with permission execution'

      let(:snapshot) { JiraTk::Permissions::PlanSnapshot.new(administrator: administrator, audit_client: audit_client) }

      it 'keeps even the internal execution entry point read-only by default', :aggregate_failures do
        expect(run.execute.to_h['status']).to eq('dry-run')
        expect(writes).to be_empty
      end

      it 'does not expose connection-bearing collaborators in inspection' do
        expect(run.inspect).to eq('#<JiraTk::Permissions::ExecutionRun>')
      end
    end
  end
end
