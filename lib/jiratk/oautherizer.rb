# frozen-string-literal: true

require 'google/apis/drive_v3'
require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'

# Encapsulate the gory details.
class OAutherizer
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  CREDENTIALS_PATH = 'credentials.json'
  # The file token.yaml stores the user's access and refresh tokens, and is
  # created automatically when the authorization flow completes for the first
  # time.
  TOKEN_PATH = 'token.yaml'
  SCOPE = [
    Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
    Google::Apis::DriveV3::AUTH_DRIVE
  ].freeze

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
    save_credentials if credentials.nil?

    # what we really want here is
    # credentials || save_credentials
    credentials
  end
end
