# frozen-string-literal: true

RSpec.describe ApiHelper do
  it 'instantiates' do
    api_keys = AccountManager.new.api_keys
    username = api_keys[:jira_id]
    password = api_keys[:jira_key]

    expect(described_class.new(username, password)).to_not be nil
  end
end
