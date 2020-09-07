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

def aws_region
  ENV['AWS_REGION']
end

def s3
  Aws::S3::Client.new(
    region: aws_region
  )
end


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

# Next up: push the issues up to S3, need to terraform a new bucket.
# Athena after S3 is working working.
#
#
# The following will load the bucket the output of the read on the file.
s3.put_object(bucket: "inventium-jira", key: "foo", body: File.new('./foo.json').read)

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
#
