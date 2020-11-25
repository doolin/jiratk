# frozen-string-literal: true

require 'pry'
require 'vcr'

Dir[File.join(File.dirname(__FILE__), '..', 'lib', 'jiratk', '**.rb')].sort.each do |f|
  require f
end

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
