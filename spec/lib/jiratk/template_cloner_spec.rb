# frozen-string-literal: true

RSpec.describe TemplateCloner do
  it 'instantiates' do
    expect(described_class.new(nil, nil)).to_not be nil
  end

  describe '#name' do
    it 'names the copied template'
  end

  describe '#url' do
    it 'returns the url of the copied template'
  end
end
