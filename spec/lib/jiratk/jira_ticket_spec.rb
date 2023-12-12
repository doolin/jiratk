# frozen_string_literal: true

require 'ostruct'

RSpec.describe JiraTicket do
  it 'instantiates' do
    params = OpenStruct.new( # rubocop:disable Style/OpenStructUse
      project_key: 'SCRUM',
      issuetype_name: 'Task',
      gem: 'rubocop',
      version: '1.0.3'
    )
    expect(described_class.new(params)).not_to be_nil
  end
end
