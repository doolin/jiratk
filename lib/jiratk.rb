# frozen_string_literal: true

# Dir[File.join(File.dirname(__FILE__), '.', 'jiratk', '**.rb')].sort.each do |f|
#   require f
# end

require_relative 'jiratk/account_manager'
require_relative 'jiratk/api_helper'
require_relative 'jiratk/s3_tools'
require_relative 'jiratk/project'
