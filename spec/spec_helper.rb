# frozen-string-literal: true

Dir[File.join(File.dirname(__FILE__), '..', 'lib', 'jiratk', '**.rb')].sort.each do |f|
  require f
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
