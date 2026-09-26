# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  use_merging false
  track_files 'lib/**/*.rb'
  add_filter '/spec/'
  add_group('New code') { |file| file.filename.match?(%r{/lib/jiratk/(tickets|permissions)/}) }
end

SimpleCov.at_exit do
  result = SimpleCov.result
  result.format!
  new_code = result.groups.fetch('New code')
  puts "New code: #{new_code.covered_percent.round(2)}% lines, #{new_code.branch_covered_percent.round(2)}% branches"
  incomplete = new_code.reject do |file|
    file.covered_percent == 100 && file.branches_coverage_percent == 100
  end
  unless incomplete.empty?
    warn "New code requires 100% line and branch coverage: #{incomplete.map(&:filename).join(', ')}"
    exit 2
  end
end

require 'vcr'
require 'webmock/rspec'

lib_root = File.expand_path('../lib/jiratk', __dir__)
Dir[File.join(lib_root, '**', '*.rb')].each { |f| require f }

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :webmock
  config.configure_rspec_metadata!
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def remove_secrets
  interactions = VCR.current_cassette.new_recorded_interactions
  redacted = '<REDACTED>'

  interactions.each do |i|
    i.request.headers['Authorization'][0] = redacted
    i.response.headers['Set-Cookie'] = redacted
    i.response.headers['X-Aaccountid'][0] = redacted
  end
end
