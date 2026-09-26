# frozen_string_literal: true

RSpec.describe JiraTk::Tickets::Client do
  subject(:client) { described_class.new(account_manager: account, api_helper: api) }

  let(:account) { instance_double(AccountManager, jira_url: 'https://example.atlassian.net/') }
  let(:api) { instance_spy(ApiHelper) }
  let(:url) { 'https://example.atlassian.net/rest/api/3/issue/GEN-1' }
  let(:document) { { 'type' => 'doc', 'version' => 1, 'content' => [] } }
  let(:fields) { { 'summary' => 'Discovery', 'description' => document, 'updated' => '2026-09-25T12:00:00Z' } }
  let(:issue) { { 'key' => 'GEN-1', 'fields' => fields } }
  let(:response) { instance_double(RestClient::Response, code: 200, body: JSON.generate(issue)) }
  let(:proposed) { JiraTk::Tickets::Description.new(document).append(heading: 'Testing', text: 'Use coverage.') }
  let(:verified) do
    body = JSON.generate(issue.merge('fields' => fields.merge('description' => proposed)))
    instance_double(RestClient::Response, code: 200, body: body)
  end

  before do
    allow(response).to receive(:body) { JSON.generate(issue) }
    allow(api).to receive(:get).and_return(response)
  end

  describe '#get' do
    it 'returns the requested ticket' do
      expect(client.get('GEN-1')).to eq(issue)
    end

    it 'uses the configured origin and requests only ticket fields' do
      client.get('GEN-1')

      expect(api).to have_received(:get).with(url, { fields: 'summary,status,parent,description,updated,project,issuetype,labels' })
    end

    it 'omits unrequested response data' do
      fields['sensitive'] = 'omit this'

      expect(client.get('GEN-1')['fields']).not_to have_key('sensitive')
    end

    [nil, '', 'GEN-0', '../GEN-1', 'GEN-1?expand=all'].each do |invalid|
      it 'rejects invalid keys before making a request' do
        expect { client.get(invalid) }.to raise_error(JiraTk::Tickets::Error, /Invalid Jira issue key/)
        expect(api).not_to have_received(:get)
      end
    end

    [301, 400, 401, 403, 404, 429, 500].each do |status|
      it "rejects HTTP #{status} without exposing the response" do
        allow(response).to receive_messages(code: status, body: 'secret response')

        expect { client.get('GEN-1') }.to raise_error(JiraTk::Tickets::Error, "Ticket read failed (HTTP #{status})")
      end
    end

    it 'rejects malformed JSON without exposing it' do
      allow(response).to receive(:body).and_return('secret invalid JSON')

      expect { client.get('GEN-1') }.to raise_error(JiraTk::Tickets::Error, 'Ticket read returned invalid JSON')
    end

    [[], { 'key' => 'GEN-2' }].each do |invalid|
      it 'rejects unexpected ticket identities' do
        allow(response).to receive(:body).and_return(JSON.generate(invalid))

        expect { client.get('GEN-1') }.to raise_error(JiraTk::Tickets::Error, /unexpected issue/)
      end
    end

    [nil, {}, { 'description' => nil }].each do |invalid|
      it 'rejects incomplete ticket fields' do
        issue['fields'] = invalid

        expect { client.get('GEN-1') }.to raise_error(JiraTk::Tickets::Error, /required fields/)
      end
    end

    [RestClient::Exception, SocketError, Timeout::Error, IOError, Errno::ECONNRESET].each do |error|
      it 'sanitizes transport errors' do
        allow(api).to receive(:get).and_raise(error, 'secret transport details')

        expect { client.get('GEN-1') }.to raise_error(JiraTk::Tickets::Error, /\AJira request failed;/)
      end
    end
  end

  describe '#append_description' do
    it 'previews by default without writing' do
      result = client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.')

      expect(result).to eq('key' => 'GEN-1', 'status' => 'dry-run', 'description' => proposed)
      expect(api).not_to have_received(:put)
    end

    it 'requires Boolean true for apply' do
      client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: 'false')

      expect(api).not_to have_received(:put)
    end

    it 'skips an already-applied section' do
      fields['description'] = proposed
      result = client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true)

      expect(result['status']).to eq('unchanged')
      expect(api).not_to have_received(:put)
    end

    it 'updates only the description and verifies it' do
      allow(api).to receive(:get).and_return(response, response, verified)
      allow(api).to receive(:put).and_return(instance_double(RestClient::Response, code: 204))
      result = client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true)

      expect(api).to have_received(:put).with(url, { fields: { description: proposed } }).once
      expect(result['status']).to eq('applied')
    end

    it 'stops when the ticket changed during preparation' do
      allow(api).to receive(:get).and_return(response, verified)

      expect { client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true) }
        .to raise_error(JiraTk::Tickets::Error, /changed during preparation/)
      expect(api).not_to have_received(:put)
    end

    it 'reports update failures without replaying the write' do
      allow(api).to receive(:put).and_return(instance_double(RestClient::Response, code: 403))

      expect { client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true) }
        .to raise_error(JiraTk::Tickets::Error, /HTTP 403/)
      expect(api).to have_received(:put).once
    end

    it 'reports an uncertain write without retrying' do
      allow(api).to receive(:put).and_raise(Timeout::Error, 'secret details')

      expect { client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true) }
        .to raise_error(JiraTk::Tickets::Error, /outcome may be unknown/)
      expect(api).to have_received(:put).once
    end

    it 'fails if readback does not contain the proposed description' do
      allow(api).to receive(:put).and_return(instance_double(RestClient::Response, code: 204))

      expect { client.append_description('GEN-1', heading: 'Testing', text: 'Use coverage.', apply: true) }
        .to raise_error(JiraTk::Tickets::Error, /could not be verified/)
    end
  end

  describe 'configuration' do
    [nil, 'http://example.test', 'https://user:secret@example.test', 'https://example.test/path',
     'https://example.test?q=secret', 'https://example.test/#secret', 'not a URL'].each do |url|
      it 'rejects unsafe or missing origins without displaying them' do
        allow(account).to receive(:jira_url).and_return(url)

        expect { client }.to raise_error(JiraTk::Tickets::Error, 'Jira URL must be an HTTPS site origin')
      end
    end

    it 'builds the existing helper with account credentials' do
      allow(account).to receive(:api_keys).and_return(jira_id: 'synthetic-user', jira_key: 'synthetic-key')
      allow(ApiHelper).to receive(:new).and_return(api)
      described_class.new(account_manager: account).get('GEN-1')

      expect(ApiHelper).to have_received(:new).with('synthetic-user', 'synthetic-key')
    end

    [nil, '', ' '].each do |missing|
      it 'rejects missing credentials' do
        allow(account).to receive(:api_keys).and_return(jira_id: 'synthetic-user', jira_key: missing)

        expect { described_class.new(account_manager: account) }.to raise_error(JiraTk::Tickets::Error, /credentials/)
      end
    end
  end
end
