# frozen_string_literal: true

require_relative '../../../support/permission_discovery'

RSpec.describe JiraTk::Permissions::Pages do
  subject(:pages) { described_class.new(connection) }

  include_context 'with permission discovery'

  context 'with multiple pages and an untrusted next-page link' do
    before do
      first = page([{ 'groupId' => 'one' }], total: 3, last: false).merge('nextPage' => 'https://untrusted.test')
      jira_get('group/bulk', first, params: { startAt: 0, maxResults: 50 })
      jira_get('group/bulk', page([{ 'groupId' => 'two' }], offset: 1, total: 3, last: false),
               params: { startAt: 1, maxResults: 50 })
      jira_get('group/bulk', page([{ 'groupId' => 'three' }], offset: 2, total: 3),
               params: { startAt: 2, maxResults: 50 })
    end

    it 'reads every page using the actual number returned' do
      expect(pages.read('/rest/api/3/group/bulk')).to eq(
        [{ 'groupId' => 'one' }, { 'groupId' => 'two' }, { 'groupId' => 'three' }]
      )
    end

    it 'ignores server links' do
      pages.read('/rest/api/3/group/bulk')

      expect(a_request(:get, 'https://untrusted.test')).not_to have_been_made
    end
  end

  it 'accepts an explicitly complete empty list' do
    jira_get('group/bulk', page([]), params: { startAt: 0, maxResults: 50 })

    expect(pages.read('/rest/api/3/group/bulk')).to eq([])
  end

  [nil, [], { 'values' => nil }, { 'startAt' => 1 }, { 'startAt' => 0.0 },
   { 'maxResults' => nil }, { 'maxResults' => 0 },
   { 'maxResults' => 1, 'values' => [{}, {}], 'total' => 2 }, { 'total' => nil }, { 'total' => -1 },
   { 'isLast' => nil }, { 'isLast' => 'false' }, { 'isLast' => true, 'total' => 2 },
   { 'isLast' => false }, { 'isLast' => false, 'total' => 2, 'values' => [] }].each do |invalid|
    it "rejects incomplete or invalid pagination #{invalid.inspect}" do
      response = invalid.is_a?(Hash) ? page([{}]).merge(invalid) : invalid
      jira_get('group/bulk', response, params: { startAt: 0, maxResults: 50 })

      expect { pages.read('/rest/api/3/group/bulk') }.to raise_error(error_class)
    end
  end

  it 'rejects an inventory that changes during pagination' do
    jira_get('group/bulk', page([{}], total: 2, last: false), params: { startAt: 0, maxResults: 50 })
    jira_get('group/bulk', page([{}], offset: 1, total: 3, last: false), params: { startAt: 1, maxResults: 50 })

    expect { pages.read('/rest/api/3/group/bulk') }.to raise_error(error_class, /total changed/)
  end
end
