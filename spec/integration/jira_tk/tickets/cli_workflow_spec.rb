# frozen_string_literal: true

require 'stringio'
require_relative '../../../support/ticket_workflow'

RSpec.describe JiraTk::Tickets::Cli do
  subject(:cli) { described_class.new(out: stdout_buffer, err: errors) }

  include_context 'with ticket workflow'

  let(:stdout_buffer) { StringIO.new }
  let(:errors) { StringIO.new }

  it 'previews a transition through the real client without writing', :aggregate_failures do
    expect(cli.run(%w[transition GEN-1 --to Done])).to eq(0)
    expect(JSON.parse(stdout_buffer.string)).to include('status' => 'dry-run', 'transition' => expected_route)
    expect(WebMock).not_to have_requested(:post, "#{ticket_url}/transitions")
  end

  it 'lists destinations through the real client', :aggregate_failures do
    expect(cli.run(%w[transitions GEN-1])).to eq(0)
    expect(JSON.parse(stdout_buffer.string)['transitions']).to eq([expected_route])
  end

  context 'when applying' do
    before do
      stub_ticket_states({}, {}, { 'status' => destination })
      stub_transition
    end

    it 'prints verified applied evidence', :aggregate_failures do
      expect(cli.run(%w[transition GEN-1 --to Done --apply])).to eq(0)
      expect(JSON.parse(stdout_buffer.string)).to include('status' => 'applied', 'current' => destination)
      expect(errors.string).to be_empty
    end

    it 'keeps transport diagnostics out of stdout' do
      expect { cli.run(%w[transition GEN-1 --to Done --apply]) }.not_to output.to_stdout
    end
  end

  it 'prints only a sanitized error when a write fails', :aggregate_failures do
    stub_transition(status: 400)
    expect(cli.run(%w[transition GEN-1 --to Done --apply])).to eq(1)
    expect(errors.string).to eq("Ticket transition failed (HTTP 400); inspect before retrying\n")
    expect(stdout_buffer.string).to be_empty
  end
end
