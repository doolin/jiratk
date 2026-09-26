# frozen_string_literal: true

require_relative '../../../support/permission_execution'
require_relative '../../../support/permissions_cli'

RSpec.describe JiraTk::Permissions::Cli do
  include_context 'with permission execution'
  include_context 'with permissions CLI output'

  let(:execute_args) { ['execute', '--plan', plan_path] + service_args }

  before { File.write(plan_path, plan.dump) }

  it 'previews a saved plan without writing by default', :aggregate_failures do
    expect(cli.run(execute_args)).to eq(0)
    expect(JSON.parse(output.string)).to include('status' => 'dry-run', 'plan_digest' => plan.to_h['digest'])
    expect(writes).to be_empty
  end

  it 'applies the reviewed plan through the existing executor', :aggregate_failures do
    expect(cli.run(execute_args + ['--apply'])).to eq(0)
    expect(JSON.parse(output.string)).to include('status' => 'applied', 'write_attempts' => [2, 3, 7])
    expect(writes).to eq([10_700, 10_800, :delete])
    expect(output.string).not_to include('synthetic', origin, audit_gateway)
  end

  it 'reports failure after an attempted write as exit 3', :aggregate_failures do
    world[:on_post] = ->(_grant) { { status: 403, body: 'private denial' } }
    expect(cli.run(execute_args + ['--apply'])).to eq(3)
    expect(JSON.parse(output.string)).to include('status' => 'failed', 'write_attempts' => [2])
    expect(writes).to eq([10_700])
    expect(output.string).not_to include('private denial')
  end

  it 'stops on preflight drift and returns the failure evidence', :aggregate_failures do
    world[:grants].pop
    expect(cli.run(execute_args + ['--apply'])).to eq(2)
    expect(JSON.parse(output.string)).to include('status' => 'failed', 'write_attempts' => [])
    expect(writes).to be_empty
  end

  it 'rejects a changed saved plan before execution', :aggregate_failures do
    File.write(plan_path, JSON.generate(plan.to_h.merge('steps' => [])))
    expect(cli.run(execute_args + ['--apply'])).to eq(2)
    expect(output.string).to be_empty
    expect(writes).to be_empty
  end

  it 'reports a missing input file without exposing its path', :aggregate_failures do
    expect(cli.run(['execute', '--plan', File.join(directory, 'secret-path')] + service_args)).to eq(2)
    expect(errors.string).to eq("Unable to read or write command file\n")
    expect(writes).to be_empty
  end

  it 'handles an invalid file path without echoing arguments', :aggregate_failures do
    expect(cli.run(['execute', '--plan', "secret\0path"] + service_args)).to eq(2)
    expect(errors.string).not_to include('secret')
    expect(writes).to be_empty
  end
end
