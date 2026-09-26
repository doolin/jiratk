# frozen_string_literal: true

RSpec.describe JiraTk::Tickets::Task do
  subject(:task) { described_class.new(**options) }

  let(:options) { { project: 'GEN', summary: 'Ticket tools', text: 'Maintain tickets.', label: 'ticket-tools' } }

  [{ project: 'GEN" OR project = "PAH' }, { label: 'bad label' }, { summary: '' },
   { summary: 'x' * 256 }, { text: '' }].each do |invalid|
    it 'rejects invalid task inputs before producing a payload' do
      expect { described_class.new(**options.merge(invalid)) }.to raise_error(JiraTk::Tickets::Error)
    end
  end

  it 'does not include legacy site-specific custom fields or time estimates' do
    expect(task.to_h.fetch(:fields).keys).to contain_exactly(:project, :issuetype, :summary, :description, :labels)
  end
end
