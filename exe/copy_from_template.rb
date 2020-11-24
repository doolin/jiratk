#!/usr/bin/env ruby
# frozen-string-literal: true

require 'google/apis/drive_v3'
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

require 'ap'
require 'pry'

require_relative '../lib/jiratk'

APPLICATION_NAME = 'Drive API Ruby Quickstart'

class FileAuth < OAutherizer
  TOKEN_PATH = 'file_token.yaml'
end

fileservice = Google::Apis::DriveV3::DriveService.new
fileservice.client_options.application_name = APPLICATION_NAME
fileservice.authorization = FileAuth.new.authorize

# Make a copy and rename in the same folder
# https://docs.google.com/spreadsheets/d/1kgLR6IMDDrhy2pgZy106tiSoSbCY0a105xRfK4t7jU8/edit#gid=1342191115
source_id = '1kgLR6IMDDrhy2pgZy106tiSoSbCY0a105xRfK4t7jU8'
new_file = fileservice.copy_file(source_id)
fileservice.update_file(new_file.id, Google::Apis::DriveV3::File.new(name: '1 AAA Estimation [deleteme]'))
