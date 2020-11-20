# frozen-string-literal: true

RSpec.describe CsvWriter do
  it 'instantiates' do
    expect(described_class.new).to_not be nil
  end
end
