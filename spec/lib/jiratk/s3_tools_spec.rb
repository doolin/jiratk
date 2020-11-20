# frozen-string-literal: true

RSpec.describe S3Tools do
  describe '#region' do
    let(:region) { 'foo' }

    it 'finds current region' do
      ENV['AWS_REGION'] = region
      expect(described_class.new.region).to eq region
    end

    xit 'raises if region not specified' do
      ENV['AWS_REGION'] = nil

      expect do
        described_class.new.region
      end.to raise_error(Aws::Errors::MissingRegionError)
    end
  end

  describe '#client' do
    it 'acquires an S3 client instance' do
      expect(described_class.new.client(stub_responses: true)).not_to be nil
    end
  end

  describe '#write' do
    it 'writes to s3'
  end
end
