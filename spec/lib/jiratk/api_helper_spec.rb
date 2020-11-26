# frozen-string-literal: true

RSpec.describe ApiHelper, :vcr do
  after(:each) do
    remove_secrets if VCR.current_cassette.recording?
  end

  let(:api_keys) { AccountManager.new.api_keys }

  it 'instantiates' do
    username = api_keys[:jira_id]
    password = api_keys[:jira_key]

    expect(described_class.new(username, password)).to_not be nil
  end

  # TODO: this should really be part of the AccountManager spec.
  it 'sends a GET', :vcr do
    username = api_keys[:jira_id]
    password = api_keys[:jira_key]
    url = 'https://doolin.atlassian.net/rest/api/3/project/search'
    api_helper = described_class.new(username, password)
    expected = %w[ADMIN BST FIN GEN PLANT SCRUM TASKLETS]

    response = api_helper.get(url, {})
    response_json = JSON.parse(response.body)
    actual = response_json['values'].map { |value| value['key'] }

    expect(actual).to eq expected
  end
end
