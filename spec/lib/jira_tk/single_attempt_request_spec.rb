# frozen_string_literal: true

RSpec.describe JiraTk::SingleAttemptRequest do
  subject(:request) { described_class.new(method: :delete, url: 'https://example.test') }

  it 'disables underlying Net::HTTP retries on uncertain mutations' do
    expect(request.net_http_object('example.test', 443).max_retries).to eq(0)
  end
end
