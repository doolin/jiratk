# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe JiraTk::Pah::Jql do
  describe '.scope' do
    it 'scopes empty JQL to project PAH' do
      expect(described_class.scope('')).to eq('project = PAH')
    end

    it 'wraps a user fragment in project = PAH AND (...)' do
      expect(described_class.scope('status = Backlog'))
        .to eq('project = PAH AND (status = Backlog)')
    end

    it 'appends ORDER BY without illegal AND (...)' do
      expect(described_class.scope('ORDER BY created DESC'))
        .to eq('project = PAH ORDER BY created DESC')
    end

    it 'rejects JQL that targets another project' do
      expect { described_class.scope('project = GEN') }
        .to raise_error(JiraTk::Pah::Error, /other than PAH/)
    end

    it 'rejects project in (...)' do
      expect { described_class.scope('project in (PAH, GEN)') }
        .to raise_error(JiraTk::Pah::Error, /other than PAH/)
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
