# frozen_string_literal: true

RSpec.describe AssessmentTicket do
  it 'instantiates' do
    expect(described_class.new(OpenStruct.new({}))).not_to be_nil # rubocop:disable Style/OpenStructUse
  end
end
