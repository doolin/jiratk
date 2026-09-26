# frozen_string_literal: true

require_relative '../../../support/permission_discovery'

RSpec.describe JiraTk::Permissions::Connection do
  subject(:read) { connection.get('/rest/api/3/myself') }

  include_context 'with permission discovery'

  it 'uses the existing private administrator configuration', :aggregate_failures do
    request = jira_get('myself', { 'accountId' => 'admin-account' })

    expect(read).to eq('accountId' => 'admin-account')
    expect(request).to have_been_requested.once
  end

  it 'keeps configuration out of object inspection' do
    expect(connection.inspect).to eq('#<JiraTk::Permissions::Connection>')
  end

  it 'keeps credentials out of transport inspection' do
    expect(ApiHelper.new('synthetic-admin', 'synthetic-secret').inspect).to eq('#<ApiHelper>')
  end

  [nil, '', ' '].each do |missing|
    %w[DOOLIN_JIRA_URL DOOLIN_JIRA_ID DOOLIN_JIRA_API].each do |key|
      it "rejects missing configuration in #{key}" do
        allow(ENV).to receive(:fetch).with(key, nil).and_return(missing)

        expect { connection }.to raise_error(error_class, 'Expected a nonblank Jira string')
      end
    end
  end

  describe 'endpoint validation' do
    ['http://example.test', 'https://user:secret@example.test', 'https://example.test?token=secret',
     'https://example.test/#secret', 'https:/', 'not a URI', 'https://example.test/path',
     'https://api.atlassian.com/ex/jira/bad-id',
     'https://untrusted.test/ex/jira/00000000-1111-2222-3333-444444444444'].each do |endpoint|
      it 'rejects unsafe endpoints without retaining their text in errors', :aggregate_failures do
        expect { described_class.service_account(base_url: endpoint, token: 'synthetic-bearer') }
          .to raise_error(error_class) { |error|
                expect(error.full_message).not_to include(endpoint, 'synthetic-bearer')
              }
      end
    end

    it 'normalizes a trailing slash and hostname case' do
      reader = described_class.service_account(base_url: 'https://PERMISSIONS.example.test/', token: 'synthetic-bearer')
      jira_get('myself', {}, authorization: 'Bearer synthetic-bearer')

      expect(reader.get('/rest/api/3/myself')).to eq({})
    end

    [nil, '', ' '].each do |token|
      it 'does not fall back to administrator credentials for a missing service token' do
        expect { described_class.service_account(base_url: origin, token: token) }.to raise_error(error_class)
      end
    end

    ["synthetic\nsecret", "synthetic\tsecret", 'synthetic secret'].each do |token|
      it 'rejects credentials that could produce unsafe HTTP header errors' do
        expect { described_class.service_account(base_url: origin, token: token) }
          .to raise_error(error_class, 'Invalid Jira credential')
      end
    end

    ['https://untrusted.test/rest/api/3/myself', '/rest/api/3/../myself',
     '/rest/api/3/myself?token=secret'].each do |path|
      it 'rejects paths that could redirect or escape the configured API' do
        expect { connection.get(path) }.to raise_error(error_class, 'Invalid Jira resource path')
      end
    end
  end

  describe 'failure handling' do
    [201, 204, 301, 302, 400, 401, 403, 404, 429].each do |status|
      it "rejects HTTP #{status} without leaking response text or following redirects", :aggregate_failures do
        stub_request(:get, "#{origin}/rest/api/3/myself")
          .to_return(status: status, body: 'synthetic-secret', headers: { 'Location' => 'https://untrusted.test' })

        expect { read }.to raise_error(error_class, "Jira read failed (HTTP #{status})")
        expect(a_request(:get, 'https://untrusted.test')).not_to have_been_made
      end
    end

    it 'sanitizes invalid JSON including its exception cause', :aggregate_failures do
      stub_request(:get, "#{origin}/rest/api/3/myself").to_return(body: 'synthetic-secret')

      expect { read }.to raise_error(error_class, 'Jira read returned invalid JSON') do |error|
        expect(error.cause).to be_nil
        expect(error.full_message).not_to include('synthetic-secret')
      end
    end

    [500, 502, 503].each do |status|
      it "sanitizes HTTP #{status} transport exceptions", :aggregate_failures do
        stub_request(:get, "#{origin}/rest/api/3/myself").to_return(status: status, body: 'synthetic-secret')

        expect { read }.to raise_error(error_class, 'Jira read failed at the transport boundary') do |error|
          expect(error.cause).to be_nil
        end
      end
    end

    [SocketError, Timeout::Error, IOError, Errno::ECONNRESET, OpenSSL::SSL::SSLError].each do |exception|
      it 'sanitizes connection failures without retrying', :aggregate_failures do
        request = stub_request(:get, "#{origin}/rest/api/3/myself").to_raise(exception.new('synthetic-secret'))

        expect { read }.to raise_error(error_class, 'Jira read failed at the transport boundary') do |error|
          expect(error.cause).to be_nil
        end
        expect(request).to have_been_requested.once
      end
    end
  end

  describe '#site_id' do
    it 'reports a stable non-secret site fingerprint' do
      jira_get('serverInfo', { 'baseUrl' => "#{origin}/" })

      expect(connection.site_id).to eq(Digest::SHA256.hexdigest(origin))
    end

    it 'rejects a server reporting a different site' do
      jira_get('serverInfo', { 'baseUrl' => 'https://other.example.test' })

      expect { connection.site_id }.to raise_error(error_class, /site identity differs/)
    end

    it 'rejects a gateway URL masquerading as the canonical site origin' do
      jira_get('serverInfo', { 'baseUrl' => 'https://api.atlassian.com/ex/jira/00000000-1111-2222-3333-444444444444' })

      expect { connection.site_id }.to raise_error(error_class, /Unsupported Jira endpoint path/)
    end
  end
end
