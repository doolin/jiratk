# frozen-string-literal: true

require 'ostruct'

RSpec.describe JiraTicket do
  it 'instantiates' do
    params = OpenStruct.new(
      project_key: 'SCRUM',
      issuetype_name: 'Task',
      gem: 'rubocop',
      version: '1.0.3'
    )
    expect(described_class.new(params)).to_not be nil
  end
end
