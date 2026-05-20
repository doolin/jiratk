# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat,RSpec/MultipleExpectations
RSpec.describe JiraTk::Pah::Client do
  let(:api) { instance_double(ApiHelper) }
  let(:client) { described_class.new(api_helper: api) }

  def api_response(body)
    double(body: body)
  end

  describe '#get' do
    it 'fetches a PAH issue' do
      body = { 'key' => 'PAH-82' }.to_json
      allow(api).to receive(:get).and_return(api_response(body))

      expect(client.get('PAH-82')['key']).to eq('PAH-82')
    end

    it 'rejects GEN keys without calling the API' do
      allow(api).to receive(:get)
      expect { client.get('GEN-1') }.to raise_error(JiraTk::Pah::Error)
      expect(api).not_to have_received(:get)
    end
  end

  describe '#search' do
    it 'searches with scoped JQL' do
      body = { 'issues' => [], 'isLast' => true }.to_json
      allow(api).to receive(:get).and_return(api_response(body))

      result = client.search('status = Backlog')
      expect(result['jql']).to eq('project = PAH AND (status = Backlog)')
    end
  end

  describe 'allowed project' do
    it 'rejects non-PAH allowed_project' do
      expect { described_class.new(api_helper: api, allowed_project: 'GEN') }
        .to raise_error(JiraTk::Pah::Error, /only supports PAH/)
    end
  end

  describe 'credentials' do
    it 'raises when credentials are missing' do
      allow(AccountManager).to receive(:new)
        .and_return(instance_double(AccountManager, api_keys: { jira_id: nil, jira_key: nil }))
      expect { described_class.new }
        .to raise_error(JiraTk::Pah::Error, /DOOLIN_JIRA_ID/)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat,RSpec/MultipleExpectations
