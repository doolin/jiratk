#!/usr/bin/env ruby
# frozen-string-literal: true

require 'google/apis/drive_v3'
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

require 'ap'
require 'pry'

require_relative './lib/jiratk/oautherizer'

APPLICATION_NAME = 'Drive API Ruby Quickstart'

service = Google::Apis::SheetsV4::SheetsService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = OAutherizer.new.authorize

# Simple class to make it easy to build the json.
class Sheet
  class << self
    def properties
      {
        properties: {
          title: '1 AAA New Software Estimation [delete me]'
        }
      }
    end
  end
end

# The idea here is to create a new spreadsheet, then copy the material from
# the existing template spreadsheet and move it to the correct folder.
# It doesn't really work, but there is enough BST here make it worthwhile to
# keep the code as an example.
@spreadsheet = service.create_spreadsheet(Sheet.properties, fields: nil)
ap "Spreadsheet ID: #{@spreadsheet.spreadsheet_id}"
new_sheet_id = @spreadsheet.spreadsheet_id

# https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/SheetsV4/CopySheetToAnotherSpreadsheetRequest.html#initialize-instance_method
# TODO: wrap this in a helper method.
new_sheet_request = Google::Apis::SheetsV4::CopySheetToAnotherSpreadsheetRequest.new
new_sheet_request.destination_spreadsheet_id = new_sheet_id # (new_sheet_id)
new_sheet_request.update!

# https://googleapis.dev/ruby/google-api-client/latest/Google/Apis/SheetsV4/SheetsService.html#copy_spreadsheet-instance_method
source_id = '1kgLR6IMDDrhy2pgZy106tiSoSbCY0a105xRfK4t7jU8'
_result = service.copy_spreadsheet(source_id, 0, new_sheet_request)

# TODO: Move the new sheet to the correct folder.
# TODO: update the template sheet to latest.

# Target folder: https://drive.google.com/drive/folders/0B69wab8Z3WTWZWVmZGZhZjAtNjdhMC00MjY3LWI3ZDQtNWNmYmYyNGIzNDg3
# Create a file in a folder, in Python, which is marginally helpful:
# https://developers.google.com/drive/api/v3/folder#create_a_file_in_a_folder
_folder_id = '0B69wab8Z3WTWZWVmZGZhZjAtNjdhMC00MjY3LWI3ZDQtNWNmYmYyNGIzNDg3'
