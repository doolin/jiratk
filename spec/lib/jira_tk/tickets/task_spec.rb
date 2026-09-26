# frozen_string_literal: true

RSpec.describe JiraTk::Tickets::Task do
  subject(:task) { described_class.new(project: 'GEN', summary: 'Audit', text: 'Audit controls.', label: 'audit') }

  ['', 'PAH-1', 'GEN-0', '../GEN-1'].each do |parent|
    it 'rejects malformed or cross-project parent keys' do
      expect { described_class.new(project: 'GEN', summary: 'Audit', text: 'Audit.', label: 'audit', parent: parent) }
        .to raise_error(JiraTk::Tickets::Error, /Parent must be an issue key/)
    end
  end

  it 'rejects an existing parented ticket when creating a standalone task' do
    fields = JSON.parse(task.to_h.to_json)['fields'].merge('parent' => { 'key' => 'GEN-1' })
    fields['issuetype']['subtask'] = false

    expect(task.matches?(fields)).to be(false)
  end
end
