# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat,RSpec/MultipleExpectations,RSpec/ExampleLength
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

  describe '#transitions' do
    it 'lists transitions for a PAH issue' do
      body = { 'transitions' => [{ 'id' => '31', 'name' => 'In Progress' }] }.to_json
      allow(api).to receive(:get).and_return(api_response(body))

      result = client.transitions('PAH-4')
      expect(result['transitions'].first['name']).to eq('In Progress')
    end

    it 'rejects GEN keys without calling the API' do
      allow(api).to receive(:get)
      expect { client.transitions('GEN-1') }.to raise_error(JiraTk::Pah::Error)
      expect(api).not_to have_received(:get)
    end
  end

  describe '#transition' do
    let(:transition_list) do
      {
        'transitions' => [
          { 'id' => '31', 'name' => 'In Progress', 'to' => { 'name' => 'In Progress' } }
        ]
      }.to_json
    end

    before { allow(api).to receive(:post) }

    it 'applies a transition by name' do
      allow(api).to receive_messages(
        get: api_response(transition_list),
        post: double(code: 204, body: '')
      )

      result = client.transition('PAH-4', to: 'In Progress')
      expect(result).to eq(
        'key' => 'PAH-4',
        'transition' => 'In Progress',
        'to' => 'In Progress'
      )
      expect(api).to have_received(:post).with(
        'https://doolin.atlassian.net/rest/api/3/issue/PAH-4/transitions',
        { transition: { id: '31' } },
        debug: false
      )
    end

    it 'rejects unknown transition names' do
      allow(api).to receive(:get).and_return(api_response(transition_list))

      expect { client.transition('PAH-4', to: 'Done') }
        .to raise_error(JiraTk::Pah::Error, /No transition named/)
      expect(api).not_to have_received(:post)
    end

    it 'rejects GEN keys without calling the API' do
      allow(api).to receive(:get)
      expect { client.transition('GEN-1', to: 'In Progress') }.to raise_error(JiraTk::Pah::Error)
      expect(api).not_to have_received(:get)
      expect(api).not_to have_received(:post)
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
# rubocop:enable RSpec/SpecFilePathFormat,RSpec/MultipleExpectations,RSpec/ExampleLength
