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

# Hopefully for dealing with service accounts
class ServiceAuth
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  # CREDENTIALS_PATH = 'credentials.json'
  CREDENTIALS_PATH = 'copytemplate-1603102060214-3c5075ffdd39.json'
  # The file token.yaml stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  TOKEN_PATH = 'token.yaml'
  SCOPE = [
    Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
    Google::Apis::DriveV3::AUTH_DRIVE
  ].freeze
  WEB_APP = 'installed'

  def client_id
    Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  end

  def token_store
    Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  end

  def authorizer
    Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  end

  def user_id
    'default'
  end

  def save_credentials
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end

  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization. If authorization is required,
  # the user's default browser will be launched to approve the request.
  #
  # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
  def authorize
    credentials = authorizer.get_credentials(user_id)
    # binding.pry
    save_credentials if credentials.nil?

    # what we really want here is
    # credentials || save_credentials
    credentials
  end
end

# Drive = Google::Apis::DriveV3
# upload_source = "testem.txt"
# drive = Drive::DriveService.new
# CREDENTIALS_PATH = 'copytemplate-1603102060214-3c5075ffdd39.json'
# credential = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
# credential = Google::Auth.from_file(CREDENTIALS_PATH)
# Drive::AUTH_DRIVE is equal to https://www.googleapis.com/auth/drive
# drive.authorization = Google::Auth.get_application_default([Drive::AUTH_DRIVE])
# file = drive.insert_file({title: 'hacking.txt'}, upload_source: upload_source)
# drive.get_file(file.id, download_dest: '/tmp/testem.txt')
# exit

fileservice = Google::Apis::DriveV3::DriveService.new
fileservice.client_options.application_name = APPLICATION_NAME

Drive = Google::Apis::DriveV3
# TODO: deal with the credentials in a system directory somehow
# /etc/google/auth/application_default_credentials.json
# binding.pry
SCOPES = [
  Drive::AUTH_DRIVE,
  Drive::AUTH_DRIVE_FILE
].freeze
fileservice.authorization = Google::Auth.get_application_default(SCOPES)
# fileservice.authorization = ServiceAuth.new.authorize

# upload_source = "testem.txt"
# file = fileservice.create_file({title: '1 AAA hacking.txt'}, upload_source: upload_source)
# fileservice.get_file(file.id, download_dest: '/tmp/testem.txt')

file_metadata = {
  name: '1 AAA Filename',
  mime_type: 'application/vnd.google-apps.document'
}

@drive = fileservice

_file = @drive.create_file(file_metadata,
                           fields: 'id,parents',
                           upload_source: StringIO.new('Text to go in file'),
                           content_type: 'text/plain') do |result, err|
  # binding.pry
  ap result
  ap err
end

# binding.pry

# current_parent = file.parents.first
# ap file.parents
# ap current_parent
@folder_id = '0B69wab8Z3WTWZWVmZGZhZjAtNjdhMC00MjY3LWI3ZDQtNWNmYmYyNGIzNDg3'
# @drive.update_file(file.id, nil, add_parents: "#{@folder_id}", remove_parents: "#{current_parent}")

# exit

# Make a copy and rename in the same folder
# https://docs.google.com/spreadsheets/d/1kgLR6IMDDrhy2pgZy106tiSoSbCY0a105xRfK4t7jU8/edit#gid=1342191115
source_id = '1kgLR6IMDDrhy2pgZy106tiSoSbCY0a105xRfK4t7jU8'
# binding.pry
new_file = fileservice.copy_file(source_id)
fileservice.update_file(new_file.id, Google::Apis::DriveV3::File.new(name: '1 AAA Estimation [deleteme]'))
