# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe JiraTk::Pah::IssueKey do
  describe '.valid?' do
    it 'accepts PAH issue keys' do
      expect(described_class.valid?('PAH-82')).to be true
    end

    it 'rejects GEN keys' do
      expect(described_class.valid?('GEN-723')).to be false
    end

    it 'rejects PAH without a number' do
      expect(described_class.valid?('PAH')).to be false
    end

    it 'rejects nil' do
      expect(described_class.valid?(nil)).to be false
    end
  end

  describe '.validate!' do
    it 'raises for non-PAH keys' do
      expect { described_class.validate!('GEN-1') }
        .to raise_error(JiraTk::Pah::Error, /PAH-<number>/)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
