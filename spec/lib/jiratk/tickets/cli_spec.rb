# frozen_string_literal: true

require 'stringio'
require 'tempfile'

RSpec.describe JiraTk::Tickets::Cli do
  subject(:cli) { described_class.new(client: client, out: output, err: errors) }

  let(:client) { instance_spy(JiraTk::Tickets::Client) }
  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }

  [[], ['help'], ['--help'], ['-h']].each do |args|
    it 'shows help without configuring a client' do
      expect(cli.run(args)).to eq(0)
      expect(output.string).to include('Usage:')
    end
  end

  it 'reads a ticket and prints JSON' do
    allow(client).to receive(:get).with('GEN-1').and_return('key' => 'GEN-1')

    expect(cli.run(%w[get GEN-1])).to eq(0)
    expect(JSON.parse(output.string)).to eq('key' => 'GEN-1')
  end

  it 'lazily builds the production client' do
    allow(JiraTk::Tickets::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get).and_return({})
    described_class.new(out: output, err: errors).run(%w[get GEN-1])

    expect(JiraTk::Tickets::Client).to have_received(:new).once
  end

  [[], ['--apply']].each do |flags|
    it 'passes section data and explicit apply intent to the library' do
      allow(client).to receive(:append_description).and_return('status' => 'ok')
      Tempfile.create('ticket-section') do |file|
        file.write('Add coverage.')
        file.flush
        args = ['append-description', 'GEN-1', '--heading', 'Testing', '--file', file.path, *flags]

        expect(cli.run(args)).to eq(0)
      end
      expect(client).to have_received(:append_description)
        .with('GEN-1', heading: 'Testing', text: 'Add coverage.', apply: flags.any?)
    end
  end

  [%w[unknown], %w[get], %w[get GEN-1 extra], %w[append-description],
   %w[append-description GEN-1], %w[append-description GEN-1 --unknown]].each do |args|
    it 'rejects invalid command arguments' do
      expect(cli.run(args)).to eq(1)
      expect(errors.string).not_to be_empty
    end
  end

  it 'reports file failures without exposing paths or file contents' do
    args = %w[append-description GEN-1 --heading Testing --file /nonexistent/section.txt]

    expect(cli.run(args)).to eq(1)
    expect(errors.string).to eq("Unable to read section file\n")
  end

  it 'reports a sanitized client error' do
    allow(client).to receive(:get).and_raise(JiraTk::Tickets::Error, 'Ticket read failed (HTTP 403)')

    expect(cli.run(%w[get GEN-1])).to eq(1)
    expect(errors.string).to eq("Ticket read failed (HTTP 403)\n")
  end

  it 'rejects invalid UTF-8 before making an API call' do
    Tempfile.create('ticket-section') do |file|
      file.binmode.write("\xFF")
      file.flush
      args = ['append-description', 'GEN-1', '--heading', 'Testing', '--file', file.path]

      expect(cli.run(args)).to eq(1)
    end
    expect(client).not_to have_received(:append_description)
  end
end
