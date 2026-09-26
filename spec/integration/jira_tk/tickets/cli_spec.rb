# frozen_string_literal: true

require 'stringio'
require 'tempfile'
require_relative '../../../support/permission_discovery'

RSpec.describe JiraTk::Tickets::Cli do
  subject(:cli) { described_class.new(out: output, err: errors) }

  include_context 'with permission discovery'

  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }
  let(:file) { Tempfile.new('subtask-description') }
  let(:args) do
    ['create-task', 'GEN', '--parent', 'GEN-1', '--summary', 'Audit permissions',
     '--label', 'permission-auditor', '--file', file.path]
  end
  let(:fields) do
    { 'project' => { 'key' => 'GEN' }, 'issuetype' => { 'name' => 'Sub-task' },
      'parent' => { 'key' => 'GEN-1' }, 'summary' => 'Audit permissions', 'labels' => ['permission-auditor'],
      'description' => { 'type' => 'doc', 'version' => 1, 'content' => [
        { 'type' => 'heading', 'attrs' => { 'level' => 2 },
          'content' => [{ 'type' => 'text', 'text' => 'Description' }] },
        { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Verify all controls.' }] }
      ] } }
  end

  before do
    file.write('Verify all controls.')
    file.flush
    stub_parent
    stub_search
    stub_child
  end

  after { file.close! }

  def stub_ticket(key, fields)
    jira_get("issue/#{key}", { 'key' => key, 'fields' => { 'description' => nil, 'updated' => 'now' }.merge(fields) },
             params: { fields: 'summary,status,parent,description,updated,project,issuetype,labels,subtasks' })
  end

  def stub_parent(changes = {})
    stub_ticket('GEN-1', { 'project' => { 'key' => 'GEN' }, 'issuetype' => { 'subtask' => false } }.merge(changes))
  end

  def stub_child(changes = {})
    stub_ticket('GEN-2', fields.merge('issuetype' => { 'name' => 'Sub-task', 'subtask' => true }).merge(changes))
  end

  def stub_search(issues = [])
    jira_get('search/jql', { 'issues' => issues, 'isLast' => true },
             params: { jql: 'project = "GEN" AND labels = "permission-auditor"', fields: 'key', maxResults: 2 })
  end

  it 'previews the exact subtask payload', :aggregate_failures do
    expect(cli.run(args)).to eq(0)
    expect(JSON.parse(output.string)).to eq('status' => 'dry-run', 'payload' => { 'fields' => fields })
    expect(a_request(:post, "#{origin}/rest/api/3/issue")).not_to have_been_made
  end

  it 'creates and verifies a subtask through the existing HTTP helper', :aggregate_failures do
    stub_request(:post, "#{origin}/rest/api/3/issue")
      .with(body: { 'fields' => fields })
      .to_return(status: 201, body: '{"key":"GEN-2"}')
    expect(cli.run(args + ['--apply'])).to eq(0)
    expect(JSON.parse(output.string)).to eq('key' => 'GEN-2', 'status' => 'created')
  end

  it 'reuses an exact labeled subtask', :aggregate_failures do
    stub_search([{ 'key' => 'GEN-2' }])
    expect(cli.run(args + ['--apply'])).to eq(0)
    expect(JSON.parse(output.string)).to eq('key' => 'GEN-2', 'status' => 'unchanged')
    expect(a_request(:post, "#{origin}/rest/api/3/issue")).not_to have_been_made
  end

  [nil, {}, { 'key' => 'GEN-3' }].each do |parent|
    it 'rejects a label attached to another parent', :aggregate_failures do
      stub_search([{ 'key' => 'GEN-2' }])
      stub_child('parent' => parent)
      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(a_request(:post, "#{origin}/rest/api/3/issue")).not_to have_been_made
    end
  end

  [{ 'project' => nil }, { 'project' => { 'key' => 'PAH' } }, { 'issuetype' => nil },
   { 'issuetype' => { 'subtask' => true } }].each do |changes|
    it 'rejects an invalid parent before creating anything', :aggregate_failures do
      stub_parent(changes)
      expect(cli.run(args + ['--apply'])).to eq(1)
      expect(a_request(:post, "#{origin}/rest/api/3/issue")).not_to have_been_made
    end
  end
end
