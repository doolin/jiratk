#!/usr/bin/env ruby

require 'pp'
require 'pry'
require 'rest-client'
require 'json'
require 'aws-sdk-s3'

require_relative 'lib/account_manager'
require_relative 'lib/api_helper'

api_url = 'https://doolin.atlassian.net/rest/api/3/search'

api_keys = AccountManager.new.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]
api_helper = ApiHelper.new(api_url)

QUERY = {
  jql: 'project = "PLANT"',
  start_at: 1
}

response = api_helper.get(QUERY)
response_json = JSON.parse(response)

ticket_count = response_json['total']

issues = response_json['issues']

issues.each do |issue|
  puts issue['key']
end
