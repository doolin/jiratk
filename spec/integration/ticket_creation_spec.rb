# frozen_string_literal: true

require 'stringio'
require 'tempfile'

RSpec.describe 'Task creation command' do
  subject(:cli) { JiraTk::Tickets::Cli.new(out: output, err: errors) }

  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }
  let(:file) { Tempfile.new('task-description') }
  let(:base) { 'https://example.atlassian.net/rest/api/3' }
  let(:args) { ['create-task', 'GEN', '--summary', 'Ticket tools', '--label', 'ticket-tools', '--file', file.path] }
  let(:payload) do
    { 'fields' => {
      'project' => { 'key' => 'GEN' }, 'issuetype' => { 'name' => 'Task' },
      'summary' => 'Ticket tools', 'labels' => ['ticket-tools'],
      'description' => {
        'type' => 'doc', 'version' => 1, 'content' => [
          { 'type' => 'heading', 'attrs' => { 'level' => 2 },
            'content' => [{ 'type' => 'text', 'text' => 'Description' }] },
          { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Maintain tickets.' }] }
        ]
      }
    } }
  end
  let(:issue) do
    { 'key' => 'GEN-1', 'fields' => payload['fields'].merge(
      'updated' => '2026-09-25', 'issuetype' => { 'name' => 'Task', 'subtask' => false }
    ) }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_URL', nil).and_return('https://example.atlassian.net')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_ID', nil).and_return('synthetic-user')
    allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_API', nil).and_return('synthetic-key')
    file.write('Maintain tickets.')
    file.flush
    stub_search('issues' => [], 'isLast' => true)
    stub_request(:get, "#{base}/issue/GEN-1")
      .with(query: { fields: 'summary,status,parent,description,updated,project,issuetype,labels' })
      .to_return(status: 200, body: issue.to_json)
  end

  after { file.close! }

  def stub_search(body)
    stub_request(:get, "#{base}/search/jql")
      .with(query: { jql: 'project = "GEN" AND labels = "ticket-tools"', fields: 'key', maxResults: 2 })
      .to_return(status: 200, body: JSON.generate(body))
  end

  it 'previews the independent HTTP payload without POSTing' do
    expect(cli.run(args)).to eq(0)
    expect(JSON.parse(output.string)).to eq('status' => 'dry-run', 'payload' => payload)
    expect(WebMock).not_to have_requested(:post, "#{base}/issue")
  end

  it 'creates a Task and reads it back through the real helpers' do
    creation = stub_request(:post, "#{base}/issue")
               .with(body: payload, basic_auth: %w[synthetic-user synthetic-key])
               .to_return(status: 201, body: '{"key":"GEN-1"}')

    expect(cli.run(args + ['--apply'])).to eq(0)
    expect(JSON.parse(output.string)).to eq('key' => 'GEN-1', 'status' => 'created')
    expect(creation).to have_been_requested.once
  end

  it 'reuses an exact existing labeled Task without POSTing' do
    stub_search('issues' => [{ 'key' => 'GEN-1' }], 'isLast' => true)

    expect(cli.run(args + ['--apply'])).to eq(0)
    expect(JSON.parse(output.string)).to eq('key' => 'GEN-1', 'status' => 'unchanged')
    expect(WebMock).not_to have_requested(:post, "#{base}/issue")
  end

  [{ 'issues' => [], 'isLast' => false }, { 'issues' => nil, 'isLast' => true },
   { 'issues' => [{ 'key' => 'GEN-1' }, { 'key' => 'GEN-2' }], 'isLast' => true }].each do |body|
    it 'rejects incomplete or ambiguous duplicate checks before writing' do
      stub_search(body)

      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(errors.string).to include('incomplete or ambiguous')
      expect(WebMock).not_to have_requested(:post, "#{base}/issue")
    end
  end

  [nil, {}].each do |entry|
    it 'rejects malformed search hits' do
      stub_search('issues' => [entry], 'isLast' => true)

      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(errors.string).to include('invalid issue')
    end
  end

  [{ 'summary' => 'Another task' }, { 'project' => { 'key' => 'PAH' } },
   { 'issuetype' => { 'name' => 'Task', 'subtask' => true } },
   { 'labels' => ['different'] }, { 'description' => nil }].each do |changes|
    it 'stops when the label belongs to a different task' do
      stub_search('issues' => [{ 'key' => 'GEN-1' }], 'isLast' => true)
      different = issue.merge('fields' => issue['fields'].merge(changes))
      stub_request(:get, "#{base}/issue/GEN-1").with(query: hash_including({}))
                                             .to_return(status: 200, body: different.to_json)

      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(errors.string).to include('identity or content differs')
      expect(WebMock).not_to have_requested(:post, "#{base}/issue")
    end
  end

  [{ status: 400, body: 'secret response', error: 'HTTP 400' },
   { status: 201, body: 'invalid', error: 'invalid JSON' },
   { status: 201, body: '[]', error: 'invalid response' },
   { status: 201, body: '{}', error: 'no issue key' }].each do |failure|
    it 'reports failed or uncertain creation without replaying the write' do
      creation = stub_request(:post, "#{base}/issue").to_return(failure.slice(:status, :body))

      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(errors.string).to include(failure.fetch(:error))
      expect(output.string).to be_empty
      expect(creation).to have_been_requested.once
    end
  end

  it 'does not retry a timed-out POST' do
    creation = stub_request(:post, "#{base}/issue").to_timeout

    expect(cli.run(args + ['--apply'])).to eq(1)
    expect(errors.string).to include('outcome may be unknown')
    expect(creation).to have_been_requested.once
  end

  it 'does not follow a POST redirect' do
    stub_request(:post, "#{base}/issue")
      .to_return(status: 307, headers: { location: 'https://untrusted.test/' })

    expect(cli.run(args + ['--apply'])).to eq(1)
    expect(errors.string).to include('HTTP 307')
    expect(WebMock).not_to have_requested(:post, 'https://untrusted.test/')
  end

  it 'rejects missing creation options' do
    expect(cli.run(%w[create-task GEN])).to eq(1)
    expect(errors.string).to include('Usage:')
    expect(WebMock).not_to have_requested(:post, "#{base}/issue")
  end
end
