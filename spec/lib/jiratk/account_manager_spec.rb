# frozen_string_literal: true

RSpec.describe AccountManager do
  subject(:account_manager) { described_class.new }

  describe '#jira_url' do
    it 'uses the configured Jira origin' do
      allow(ENV).to receive(:fetch).with('DOOLIN_JIRA_URL', nil).and_return('https://example.atlassian.net')

      expect(account_manager.jira_url).to eq('https://example.atlassian.net')
    end
  end

  it 'instantiates' do
    expect(described_class.new).not_to be_nil
  end

  describe '#api_keys' do
    it 'acquires API keys for Jira connection'
  end

  describe '#search_url' do
    it 'provides jira project API search URL' do
      expected = 'https://doolin.atlassian.net/rest/api/3/project/search'

      expect(described_class.new.search_url).to eq expected
    end
  end

  describe '#project_keys' do
    it 'lists keys for all projects'
  end
end
