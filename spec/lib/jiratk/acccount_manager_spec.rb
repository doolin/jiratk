# frozen-string-literal: true

RSpec.describe AccountManager do
  it 'instantiates' do
    expect(described_class.new).not_to be nil
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
