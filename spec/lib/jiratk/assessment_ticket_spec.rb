# frozen-string-literal: true

RSpec.describe AssessmentTicket do
  it 'instantiates' do
    expect(described_class.new(OpenStruct.new({}))).to_not be nil
  end
end
