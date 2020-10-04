#!/usr/bin/env ruby

# frozen-string-literal: true

require 'pp'
require 'ap'
require 'pry'
require 'rest-client'
require 'json'
require 'aws-sdk-s3'
require 'csv'

require_relative 'lib/account_manager'
require_relative 'lib/api_helper'

api_keys = AccountManager.new.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]

def aws_region
  ENV['AWS_REGION']
end

def s3
  @s3 ||= Aws::S3::Client.new(region: aws_region)
end

def get_issues_for(project)
  query = {
    jql: "project = \"#{project}\"",
    start_at: 1
  }

  api_url = 'https://doolin.atlassian.net/rest/api/3/search'
  api_helper = ApiHelper.new(api_url)

  response = api_helper.get(query)
  response_json = JSON.parse(response)
  # ticket_count = response_json['total']
  response_json['issues']
end

def list_issues_for(project)
  issues = get_issues_for(project)
  issues.each do |issue|
    puts issue['key']
  end
end
# list_issues_for('PLANT')

def project_list
  projects = []
  api_url = 'https://doolin.atlassian.net/rest/api/3/project/search'
  api_helper = ApiHelper.new(api_url)
  response = api_helper.get({})
  response_json = JSON.parse(response)
  response_json['values'].each do |value|
    projects << value['key']
  end

  projects
end

# Next up: push the issues up to S3, need to terraform a new bucket.
def upload_to_s3
  project_list.each do |project|
    issues = get_issues_for(project)
    issues.each do |issue|
      s3.put_object(bucket: 'inventium-jira', key: issue['key'], body: issue.to_json)
    end
  end
end

# Next round of work is writing the files to a local directory
# for convenience. This will help with generating csvs a lot.
def write_to_fixtures
  # write everything to spec/fixtures directory.
end
# write_to_fixtures

# What we really want to do is stream the json directly from the values returned
# from Jira. Some questions:
# 1. Do we want to upload every issue every time?
# 2. Or would it be better to sync instead?
#
# The first thing is to just get the Jira issues copied to S3. Then I can worry
# about duplicating existing issues.
#
# The problem with syncing is that I do not intended to keep a local copy of
# the Jira issues, so I'm not sure how syncing would work.
#
# Athena after S3 is working working.
# I think this means turning the json into csv.
#
#
# Getting json into csv means figuring out which of the json fields we want
# to extract, then getting those fields extracted.
# - Do we need headers?
# - How to deal with commas ',' in fields?
#
# At least the following to start:
# - key
# - fields::issuetype::name
# - field::timespent
# - fields::project::name
# - fields::resolution::name
# - fields::assignee::displayName

# Some example json, put this into a fixture file later.
# Schedule a ticket to periodically update the fixture file
# from collected issues.
# TODO: Replace this with a fixture from the TASKLETS project, which will be
# much more interesting.

# require_relative './spec/fixtures/plant_5'
# ap plant[:key]
# ap plant.dig(:fields, :issuetype, :name)
# ap plant.dig(:fields, :project, :name)
# ap plant.dig(:fields, :resolution, :name)
# ap plant.dig(:fields, :assignee, :displayName)
# ap plant.dig(:fields, :status, :statusCategory, :name)
# # description is going to have to have its own processor
# ap plant.dig(:fields, :description, :content)[0][:content][0][:text]

# Post an issue. Note that this works in Postman.
params = JSON.parse(File.read('./test.json'))
api_url = 'https://doolin.atlassian.net/rest/api/2/issue/'
api_helper = ApiHelper.new(api_url)
_response = api_helper.post(params)
