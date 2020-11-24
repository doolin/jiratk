#!/usr/bin/env ruby
# frozen-string-literal: true

require 'fileutils'

require_relative '../lib/jiratk'

# TODO: step 4 from https://docs.google.com/spreadsheets/d/1JD10EqecIqj8qB-kQTeCBPjxDOkpG-BZvdqX_ukX6Gs/edit#gid=0
# Create a dedicated class for provisioning these tickets, which instantiates with an
# OpenStruct containing the desired URL. Each particular ticket will subclass with
# appropriate description and summary.

# TODO: Remove this if possible.
class FileAuth < OAutherizer
  TOKEN_PATH = 'file_token.yaml'
end

APPLICATION_NAME = 'Drive API Ruby Quickstart'
fileservice = Google::Apis::DriveV3::DriveService.new
fileservice.client_options.application_name = APPLICATION_NAME
fileservice.authorization = FileAuth.new.authorize

# TODO: find a way to wrap this in a class which can be put
# elsewhere and not have the following block of code cluttering
# up the file.
api_keys = AccountManager.new.api_keys
username = api_keys[:jira_id]
password = api_keys[:jira_key]
api_url = 'https://doolin.atlassian.net/rest/api/2/issue/'
api_helper = ApiHelper.new(username, password)

# Everything above here needs to go into its own class.
# Below here is where the operator action occurs.

# TODO: this class instantiates on the id, and combines
# the Drive and Jira API calls. Probably doesn't even need
# to be a class, could be a function.
# rubocop:disable Lint/EmptyClass
class Coordinator
end
# rubocop:enable Lint/EmptyClass

require 'ostruct'

PROJECT_KEY = 'SCRUM'

foo_id = '1CdRAI61BInmvBjOfUpWsaLlskLfhNIX0Xo2q87yAkHQ'
bar_id = '1zDn2uAdwYmofTyth1Xu2V4kAYwpBqu7WHd3XfyiXEMg'
baz_id = '1n8k6QZ9hFiUgbD7LfpF618f-rCAsqhRfkKvL269ZPws'

ids = [foo_id, bar_id, baz_id]

ids.each do |id|
  tc = TemplateCloner.new(id, fileservice)
  tc.clone

  params = OpenStruct.new(
    project_key: PROJECT_KEY,
    issuetype_name: 'Task',
    url: tc.url,
    name: tc.name
  )

  params = AssessmentTicket.new(params).to_h
  api_helper.post(api_url, params)

  puts tc.url
end
