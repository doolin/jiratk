# frozen_string_literal: true

RSpec.describe JiraTk::Tickets::Description do
  subject(:description) { described_class.new(document) }

  let(:document) { { 'type' => 'doc', 'version' => 1, 'content' => [original] } }
  let(:original) { { 'type' => 'rule' } }
  let(:section) do
    [
      { 'type' => 'heading', 'attrs' => { 'level' => 2 }, 'content' => [{ 'type' => 'text', 'text' => 'Testing' }] },
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Cover failures.' }] },
      { 'type' => 'paragraph', 'content' => [{ 'type' => 'text', 'text' => 'Cover success.' }] }
    ]
  end
  let(:text) { "Cover failures.\n\nCover success." }

  it 'appends paragraphs while preserving existing nodes and document attributes' do
    document['extra'] = 'preserved'
    expected = document.merge('content' => [original, *section])

    expect(description.append(heading: ' Testing ', text: text)).to eq(expected)
  end

  it 'does not mutate the input document' do
    description.append(heading: 'Testing', text: text)

    expect(document['content']).to eq([original])
  end

  it 'starts a description when none exists' do
    result = described_class.new(nil).append(heading: 'Testing', text: text)

    expect(result).to eq('type' => 'doc', 'version' => 1, 'content' => section)
  end

  it 'leaves an identical existing section unchanged' do
    document['content'].concat(section)

    expect(description.append(heading: 'Testing', text: text)).to equal(document)
  end

  it 'recognizes an identical section followed by another heading' do
    document['content'].concat(section + [section.first.merge('content' => [{ 'text' => 'Later' }])])

    expect(description.append(heading: 'Testing', text: text)).to equal(document)
  end

  it 'rejects a heading with different content' do
    document['content'] << section.first

    expect { description.append(heading: 'Testing', text: text) }
      .to raise_error(JiraTk::Tickets::Error, /different or ambiguous/)
  end

  it 'rejects duplicate headings' do
    document['content'].concat(section * 2)

    expect { description.append(heading: 'Testing', text: text) }
      .to raise_error(JiraTk::Tickets::Error, /different or ambiguous/)
  end

  ['', '   '].each do |blank|
    it 'rejects blank headings' do
      expect { description.append(heading: blank, text: text) }.to raise_error(JiraTk::Tickets::Error, /blank/)
    end

    it 'rejects blank text' do
      expect { description.append(heading: 'Testing', text: blank) }.to raise_error(JiraTk::Tickets::Error, /blank/)
    end
  end

  [false, 'legacy text', {}, { 'type' => 'doc', 'version' => 2 },
   { 'type' => 'doc', 'version' => 1, 'content' => nil }].each do |invalid|
    it 'rejects unsupported document formats' do
      expect { described_class.new(invalid) }.to raise_error(JiraTk::Tickets::Error, /format/)
    end
  end
end
