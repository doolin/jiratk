#!/usr/bin/env ruby

# frozen-string-literal: true

require 'pp'
require 'ap'
require 'pry'
require 'rest-client'
require 'json'
require 'csv'

require_relative '../lib/jiratk/account_manager'
require_relative '../lib/jiratk/api_helper'
require_relative '../lib/jiratk/s3_tools'

api_keys = AccountManager.new.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]

# setting maxResults: 0 returns just metadata which will
# contain `total`, the number of issues in a project.
def issue_count_for(project)
  query = {
    jql: "project = \"#{project}\"",
    startAt: 0,
    maxResults: 0
  }

  api_url = 'https://doolin.atlassian.net/rest/api/3/search'
  api_helper = ApiHelper.new(api_url)

  response = api_helper.get(query)
  response_json = JSON.parse(response)
  response_json['total']
end

STEP = 50

# `startAt` works in reverse order: it indexes the latest
# ticket at 0, and works backwards from that.
def get_issues_for(project, start_at)
  query = {
    jql: "project = \"#{project}\"",
    startAt: start_at.to_s,
    maxResults: STEP
  }

  api_url = 'https://doolin.atlassian.net/rest/api/3/search'
  api_helper = ApiHelper.new(api_url)

  response = api_helper.get(query)
  response_json = JSON.parse(response)
  response_json['issues']
end

# TODO: delete this method after refactor
def list_issues_for(project)
  issues = get_issues_for(project, 0)
  issues.each do |issue|
    puts issue['key']
    # File.open("/tmp/jira/#{issue['key']}.json","w") do |f|
    #   f.write(issue)
    # end
  end
  issues
end
# _issues = list_issues_for('TASKLETS')
# binding.pry here to examine list

def project_list
  projects = []
  api_url = 'https://doolin.atlassian.net/rest/api/3/project/search'
  api_helper = ApiHelper.new(api_url)
  response = api_helper.get({})
  response_json = JSON.parse(response)
  # TODO: see if map works here, would be cleaner
  response_json['values'].each do |value|
    projects << value['key']
  end

  projects
end

def path
  @path ||= '/tmp' # or current working directory tmp, or whatever
end

# Do tasklets project first, then consider adding capability
# to write an issue as a fixture. Adding a write via dependency
# injection would be helpful.
def batch_download_for(project)
  total = issue_count_for(project)

  (0..total).step(STEP).each do |start_at|
    issues = get_issues_for(project, start_at)
    issues.each do |issue|
      puts issue['key']
      # TODO: factor this out as a DI
      File.open("#{path}/jira/#{issue['key']}.json", 'w') do |f|
        f.write(issue)
      end
    end
  end
end
batch_download_for('TASKLETS')

def s3
  @s3 ||= S3Tools.new
end

def write_to_s3
  project_list.each do |project|
    issues = get_issues_for(project, 0)
    issues.each do |issue|
      s3.write(issue)
    end
  end
end
# write_to_s3

# TODO: rewrite script in terms of DSL:
# configure:
#  jira api credentials
#  aws credentials
#  desired activity:
#    pull all tickets from every project
#    upload all tickets from every project to S3
# execute
