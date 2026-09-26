# frozen_string_literal: true

RSpec.describe JiraTk::Permissions::Readback do
  subject(:readback) { described_class.new(sleeper: ->(delay) { delays << delay }) }

  let(:delays) { [] }

  [nil, '3', 0, 6].each do |attempts|
    it 'requires a bounded integer attempt count' do
      expect { described_class.new(attempts: attempts) }.to raise_error(JiraTk::Permissions::Error, /1-5 attempts/)
    end
  end

  [nil, '1', -1, 6, Float::NAN, Float::INFINITY, Complex(1, 1)].each do |interval|
    it 'requires a bounded real interval' do
      expect { described_class.new(interval: interval) }.to raise_error(JiraTk::Permissions::Error, /0-5 second/)
    end
  end

  it 'requires a callable sleeper' do
    expect { described_class.new(sleeper: nil) }.to raise_error(JiraTk::Permissions::Error, /callable sleeper/)
  end

  it 'returns immediately when verification succeeds', :aggregate_failures do
    expect(readback.verify { true }).to be_nil
    expect(delays).to be_empty
  end

  it 'bounds unsuccessful verification', :aggregate_failures do
    expect(readback.verify { false }).to eq('category' => 'verification_pending')
    expect(delays).to eq([1, 1])
  end

  it 'retries transient read failures and can recover', :aggregate_failures do
    expect(readback.verify { delays.any? || raise(JiraTk::Permissions::Error, 'private response') }).to be_nil
    expect(delays).to eq([1])
  end

  it 'preserves unknown reads as a verification failure', :aggregate_failures do
    expect(readback.verify { raise JiraTk::Permissions::Error, 'private response' })
      .to eq('category' => 'verification_read_failed')
    expect(delays).to eq([1, 1])
  end

  it 'stops on drift without waiting for a more favorable read', :aggregate_failures do
    expect(readback.verify { raise JiraTk::Permissions::ExecutionDrift })
      .to eq('category' => 'state_changed')
    expect(delays).to be_empty
  end

  it 'does not inspect the injected callback' do
    expect(readback.inspect).to eq('#<JiraTk::Permissions::Readback>')
  end
end
