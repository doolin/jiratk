# frozen_string_literal: true

RSpec.describe CsvWriter do
  it 'instantiates' do
    expect(described_class.new).not_to be_nil
  end
end
