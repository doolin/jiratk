# frozen-string-literal: true

RSpec.describe Project do
  it 'instantiates' do
    expect(described_class.new).to_not be nil
  end

  describe '.get_issues_for' do
    it 'gets some issues'
  end

  describe '.issue_count_for' do
    it 'counts the project issues'
  end

  describe '.batch_download_for' do
    it 'downloads all issues for a project'
  end
end
