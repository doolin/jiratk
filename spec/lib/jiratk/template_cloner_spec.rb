# frozen_string_literal: true

RSpec.describe TemplateCloner do
  it 'instantiates' do
    expect(described_class.new(nil, nil)).not_to be_nil
  end

  describe '#name' do
    it 'names the copied template'
  end

  describe '#url' do
    it 'returns the url of the copied template'
  end
end
