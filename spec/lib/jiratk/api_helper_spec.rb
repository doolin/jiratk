# frozen_string_literal: true

RSpec.describe ApiHelper, :vcr do
  after do
    remove_secrets if VCR.current_cassette.recording?
  end

  let(:api_keys) { AccountManager.new.api_keys }
  let(:username) { api_keys[:jira_id] }
  let(:password) { api_keys[:jira_key] }
  let(:search_url) { 'https://doolin.atlassian.net/rest/api/3/project/search' }

  it 'instantiates' do
    expect(described_class.new(username, password)).not_to be_nil
  end

  # TODO: this should really be part of the AccountManager spec.
  it 'sends a GET', :vcr do
    response = described_class.new(username, password).get(search_url, {})
    actual = JSON.parse(response.body)['values'].map { |v| v['key'] }

    expect(actual).to eq %w[ADMIN BST FIN GEN PLANT SCRUM TASKLETS]
  end
end
