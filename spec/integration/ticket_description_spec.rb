# frozen_string_literal: true

require 'stringio'
require 'tempfile'

RSpec.describe 'Ticket description command' do
  subject(:cli) { JiraTk::Tickets::Cli.new(out: output, err: errors) }

  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }
  let(:section_file) { Tempfile.new('ticket-section') }
  let(:url) { 'https://example.atlassian.net/rest/api/3/issue/GEN-1' }
  let(:args) do
    ['append-description', 'GEN-1', '--heading', 'Testing', '--file', section_file.path, '--apply']
  end
  let(:original) do
    {
      'type' => 'doc', 'version' => 1,
      'content' => [{ 'type' => 'paragraph',
                      'content' => [{ 'type' => 'text', 'text' => 'Existing requirements',
                                      'marks' => [{ 'type' => 'strong' }] }] }]
    }
  end
  let(:expected_description) do
    original.merge('content' => [
                     *original['content'],
                     { 'type' => 'heading', 'attrs' => { 'level' => 2 },
                       'content' => [{ 'type' => 'text', 'text' => 'Testing' }] },
                     { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Cover failures.' }] }
                   ])
  end
  let(:before_read) { { 'key' => 'GEN-1', 'fields' => { 'description' => original, 'updated' => 'before' } } }
  let(:after_read) do
    { 'key' => 'GEN-1', 'fields' => { 'description' => expected_description, 'updated' => 'after' } }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_URL', nil).and_return('https://example.atlassian.net')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_ID', nil).and_return('synthetic-user')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_API', nil).and_return('synthetic-key')
    section_file.write('Cover failures.')
    section_file.flush
  end

  after { section_file.close! }

  def stub_reads(*issues)
    stub_request(:get, url)
      .with(query: { fields: 'summary,status,parent,description,updated,project,issuetype,labels,subtasks' },
            basic_auth: %w[synthetic-user synthetic-key])
      .to_return(*issues.map { |issue| { status: 200, body: JSON.generate(issue) } })
  end

  it 'preserves rich content, verifies the saved section, and makes a repeat call a no-op' do
    stub_reads(before_read, before_read, after_read)
    update = stub_request(:put, url)
             .with(body: JSON.generate(fields: { description: expected_description }),
                   basic_auth: %w[synthetic-user synthetic-key], headers: { 'Content-Type' => 'application/json' })
             .to_return(status: 204)

    expect(cli.run(args)).to eq(0)
    expect(JSON.parse(output.string)['status']).to eq('applied')
    output.truncate(0)
    output.rewind
    expect(cli.run(args)).to eq(0)
    expect(JSON.parse(output.string)['status']).to eq('unchanged')
    expect(update).to have_been_requested.once
  end

  it 'does not send a write when the second read detects another editor' do
    stub_reads(before_read, before_read.merge('fields' => before_read['fields'].merge('updated' => 'another edit')))

    expect(cli.run(args)).to eq(1)
    expect(errors.string).to include('changed during preparation')
    expect(WebMock).not_to have_requested(:put, url)
  end

  it 'rejects a redirect without sending credentials to its target' do
    stub_request(:get, url)
      .with(query: { fields: 'summary,status,parent,description,updated,project,issuetype,labels,subtasks' })
      .to_return(status: 302, headers: { location: 'https://untrusted.test/' })

    expect(cli.run(args)).to eq(1)
    expect(errors.string).to include('HTTP 302')
    expect(WebMock).not_to have_requested(:get, 'https://untrusted.test/')
    expect(WebMock).not_to have_requested(:put, url)
  end

  it 'reports an HTTP failure without printing the body or authentication values' do
    stub_request(:get, url)
      .with(query: { fields: 'summary,status,parent,description,updated,project,issuetype,labels,subtasks' })
      .to_return(status: 403, body: '{"errorMessages":["do-not-display"]}')

    expect(cli.run(args)).to eq(1)
    expect(errors.string).to eq("Ticket read failed (HTTP 403)\n")
    expect(output.string).to be_empty
    expect(WebMock).not_to have_requested(:put, url)
  end
end
