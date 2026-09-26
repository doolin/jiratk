# frozen_string_literal: true

require 'tmpdir'
require_relative '../../../support/permission_plan'

RSpec.describe JiraTk::Permissions::MarkdownFile do
  subject(:adapter) { described_class.new(path: path) }

  include_context 'with a permission repair plan'

  let(:directory) { Dir.mktmpdir('permission-evidence') }
  let(:path) { File.join(directory, 'report.md') }
  let(:report) do
    JiraTk::Permissions::Auditor.new(administrator: administrator, audit_client: audit_client,
                                     expected_account_id: 'service-account').audit
  end

  before { File.write(path, 'previous complete report') }
  after { FileUtils.remove_entry(directory) }

  it 'replaces the previous file completely and restricts file permissions', :aggregate_failures do
    adapter.save(report)
    expect(File.read(path)).to include(report.matrix, '"status": "mismatch"')
    expect(File.read(path)).not_to include('previous complete report')
    expect(File.stat(path).mode & 0o777).to eq(0o600)
    expect(Dir.children(directory)).to eq(['report.md'])
  end

  context 'when the final rename fails' do
    before { allow(File).to receive(:rename).and_raise(Errno::EACCES, 'sensitive-path') }

    it 'reports a sanitized failure without its original cause', :aggregate_failures do
      expect { adapter.save(report) }.to raise_error(error_class, /Unable to save audit evidence/) do |error|
        expect(error.cause).to be_nil
        expect(error.message).not_to include('sensitive-path')
      end
    end

    it 'preserves the old report and removes the temporary file', :aggregate_failures do
      expect { adapter.save(report) }.to raise_error(error_class)
      expect(File.read(path)).to eq('previous complete report')
      expect(Dir.children(directory)).to eq(['report.md'])
    end
  end

  context 'when a write is interrupted' do
    before do
      allow(Tempfile).to receive(:create).and_wrap_original do |create, *args, &block|
        create.call(*args) do |file|
          allow(file).to receive(:write).and_wrap_original do |write, content|
            write.call(content[0, 20])
            raise IOError, 'synthetic-secret'
          end
          block.call(file)
        end
      end
    end

    it 'discards partial temporary content and keeps the last report', :aggregate_failures do
      expect { adapter.save(report) }.to raise_error(error_class, /previous report preserved/)
      expect(File.read(path)).to eq('previous complete report')
      expect(Dir.children(directory)).to eq(['report.md'])
    end
  end

  it 'defaults to the ignored repository-root file', :aggregate_failures do
    root = File.expand_path('../../../..', __dir__)
    expect(described_class::DEFAULT_PATH).to eq(File.join(root, 'audit-results.md'))
    expect(File.read(File.join(root, '.gitignore')).lines.map(&:chomp)).to include('/audit-results.md')
  end

  it 'uses the default adapter through the persistence interface', :aggregate_failures do
    stub_const('JiraTk::Permissions::MarkdownFile::DEFAULT_PATH', path)
    JiraTk::Permissions::Persistence.new.save(report)
    expect(File.read(path)).to include(report.matrix)
  end

  context 'with Markdown fences in identity evidence' do
    let(:identity) { report.to_h['identity'].merge('id' => "service\n```\n# injected") }

    before do
      data = report.to_h
      unusual = JiraTk::Permissions::AuditReport.new(identity: identity, scope: data['scope'],
                                                     rows: data['projects'], timestamp: data['timestamp'])
      adapter.save(unusual)
    end

    it 'keeps the fences inert while preserving JSON', :aggregate_failures do
      markdown = File.read(path)
      json = markdown.split("```json\n").last.delete_suffix("```\n")
      expect(JSON.parse(json)['identity']).to eq(identity)
      expect(markdown.scan(/^```/).size).to eq(4)
    end
  end
end
