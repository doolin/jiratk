# frozen_string_literal: true

RSpec.describe ApiHelper do
  subject(:api) { described_class.new('synthetic-user', 'synthetic-key') }

  let(:url) { 'https://example.atlassian.net/rest/api/3/issue/GEN-1' }
  let(:payload) { { fields: { description: nil } } }

  [204, 400, 401, 403, 404, 429, 500].each do |status|
    it "returns HTTP #{status} to the caller for validation" do
      stub_request(:put, url).with(body: payload.to_json, basic_auth: %w[synthetic-user synthetic-key])
                             .to_return(status: status)

      expect(api.put(url, payload).code).to eq(status)
    end
  end

  it 'does not print response bodies' do
    stub_request(:put, url).to_return(status: 400, body: 'secret response')

    expect { api.put(url, payload) }.not_to output.to_stdout
  end

  it 'does not follow update redirects' do
    stub_request(:put, url).to_return(status: 307, headers: { location: 'https://untrusted.test/' })

    expect(api.put(url, payload).code).to eq(307)
    expect(WebMock).not_to have_requested(:put, 'https://untrusted.test/')
  end

  it 'does not follow read redirects' do
    stub_request(:get, url).to_return(status: 302, headers: { location: 'https://untrusted.test/' })

    expect(api.get(url, {}).code).to eq(302)
    expect(WebMock).not_to have_requested(:get, 'https://untrusted.test/')
  end
end
