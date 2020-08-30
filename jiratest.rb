#!/usr/bin/env ruby

require 'pp'
require 'pry'
require 'rest-client'
require 'json'
require 'aws-sdk-s3'

require_relative 'lib/account_manager'
require_relative 'lib/api_helper'

api_keys = AccountManager.new.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]


def list_issues_for(project)
  query = {
    jql: "project = \"#{project}\"",
    start_at: 1
  }

  api_url = 'https://doolin.atlassian.net/rest/api/3/search'
  api_helper = ApiHelper.new(api_url)

  response = api_helper.get(query)
  response_json = JSON.parse(response)
  ticket_count = response_json['total']
  issues = response_json['issues']
  issues.each do |issue|
    puts issue['key']
  end
end
list_issues_for('PLANT')

# Get a list of projects
def project_list
  api_url = 'https://doolin.atlassian.net/rest/api/3/project/search'
  api_helper = ApiHelper.new(api_url)
  response = api_helper.get({})
  response_json = JSON.parse(response)
  response_json['values'].each do |value|
   puts value['key']
  end
end
project_list