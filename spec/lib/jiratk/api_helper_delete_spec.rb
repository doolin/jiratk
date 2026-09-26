# frozen_string_literal: true

RSpec.describe ApiHelper do
  subject(:api) { described_class.new('synthetic-user', 'synthetic-secret') }

  let(:url) { 'https://example.test/rest/api/3/permissionscheme/10003/permission/10592' }

  [204, 302, 403, 404, 429, 500].each do |status|
    it "returns HTTP #{status} without parsing or printing the body" do
      stub_request(:delete, url).with(basic_auth: %w[synthetic-user synthetic-secret]).to_return(status: status)
      expect(api.delete(url).code).to eq(status)
    end
  end

  it 'does not print deletion responses' do
    stub_request(:delete, url).to_return(status: 403, body: 'secret')
    expect { api.delete(url) }.not_to output.to_stdout
  end

  it 'does not follow deletion redirects', :aggregate_failures do
    stub_request(:delete, url).to_return(status: 307, headers: { location: 'https://untrusted.test/' })
    expect(api.delete(url).code).to eq(307)
    expect(WebMock).not_to have_requested(:delete, 'https://untrusted.test/')
  end

  it 'supports separately injected bearer authentication for deletion' do
    stub_request(:delete, url).with(headers: { 'Authorization' => 'Bearer synthetic-bearer' }).to_return(status: 204)
    expect(described_class.new.delete(url, bearer_token: 'synthetic-bearer').code).to eq(204)
  end

  it 'supports bearer authentication for grant creation' do
    stub_request(:post, url).with(headers: { 'Authorization' => 'Bearer synthetic-bearer' }).to_return(status: 201)
    expect(described_class.new.post(url, {}, debug: false, bearer_token: 'synthetic-bearer').code).to eq(201)
  end
end
