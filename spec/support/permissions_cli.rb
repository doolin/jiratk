# frozen_string_literal: true

require 'stringio'
require 'tmpdir'

RSpec.shared_context 'with permissions CLI output' do
  subject(:cli) { described_class.new(out: output, err: errors, environment: environment) }

  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }
  let(:directory) { Dir.mktmpdir('permissions-cli') }
  let(:environment) { { 'SERVICE_URL' => audit_gateway, 'SERVICE_TOKEN' => 'synthetic-bearer' } }
  let(:plan_path) { File.join(directory, 'reviewed.json') }

  def service_args
    %w[--service-url-env SERVICE_URL --service-token-env SERVICE_TOKEN]
  end

  after { FileUtils.remove_entry(directory) }
end
