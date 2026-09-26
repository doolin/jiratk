# frozen_string_literal: true

RSpec.describe JiraTk::Tickets::Transition do
  subject(:transition) { described_class.new(data) }

  let(:data) do
    { 'id' => '31', 'name' => 'Finish', 'to' => { 'id' => '5', 'name' => 'Done' },
      'hasScreen' => false, 'fields' => {} }
  end
  let(:error_class) { JiraTk::Tickets::Error }

  [nil, [], {}, { 'id' => 5 }, { 'id' => '0' }, { 'id' => '../1' }, { 'id' => '5' },
   { 'id' => '5', 'name' => 1 }, { 'id' => '5', 'name' => ' ' }].each do |value|
    it 'rejects malformed identities' do
      expect { described_class.identity(value) }.to raise_error(error_class, /identity metadata/)
    end
  end

  it 'strips unrelated identity fields' do
    expect(described_class.identity(data)).to eq('id' => '31', 'name' => 'Finish')
  end

  it 'rejects an invalid destination identity' do
    data['to'] = nil
    expect { transition }.to raise_error(error_class, /identity metadata/)
  end

  %w[hasScreen isAvailable].each do |flag|
    [nil, 'false', 1].each do |invalid|
      it 'rejects missing or non-Boolean flags' do
        data[flag] = invalid
        expect { transition }.to raise_error(error_class, /workflow flags/)
      end
    end
  end

  [nil, [], 'invalid'].each do |fields|
    it 'rejects missing field metadata' do
      data['fields'] = fields
      expect { transition }.to raise_error(error_class, /omitted transition field metadata/)
    end
  end

  it 'rejects malformed field entries' do
    data['fields'] = { 'resolution' => nil }
    expect { transition }.to raise_error(error_class, /invalid transition field metadata/)
  end

  it 'rejects unknown field requirements' do
    data['fields'] = { 'resolution' => {} }
    expect { transition }.to raise_error(error_class, /workflow flags/)
  end

  it 'lists required field names in a stable order' do
    data['fields'] = { 'z' => { 'required' => true }, 'a' => { 'required' => true }, 'b' => { 'required' => false } }
    expect(transition.to_h['required_fields']).to eq(%w[a z])
  end

  it 'rejects a route requiring fields even if Jira supplies defaults' do
    data['fields'] = { 'resolution' => { 'required' => true, 'hasDefaultValue' => true } }
    expect { described_class.select([transition.to_h], 'Done') }.to raise_error(error_class, /requires fields/)
  end

  it 'rejects explicitly unavailable transitions' do
    data['isAvailable'] = false
    expect { described_class.select([transition.to_h], 'Done') }.to raise_error(error_class, /unavailable/)
  end

  it 'allows optional screen fields without supplying any' do
    data['hasScreen'] = true
    data['isAvailable'] = true
    data['fields'] = { 'comment' => { 'required' => false } }
    expect(described_class.select([transition.to_h], 'Done')).to eq(transition.to_h)
  end
end
