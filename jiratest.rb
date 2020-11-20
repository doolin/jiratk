#!/usr/bin/env ruby

# frozen-string-literal: true

require 'pp'
require 'ap'
require 'pry'
require 'rest-client'
require 'json'
require 'csv'

require_relative 'lib/jiratk/account_manager'
require_relative 'lib/jiratk/api_helper'
require_relative 'lib/jiratk/s3_tools'

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

# Do tasklets project first
def batch_download_for(project)
  total = issue_count_for(project)

  (0..total).step(STEP).each do |start_at|
    issues = get_issues_for(project, start_at)
    issues.each do |issue|
      puts issue['key']
      File.open("/tmp/jira/#{issue['key']}.json", 'w') do |f|
        f.write(issue)
      end
    end
  end
end
# batch_download_for('TASKLETS')

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
write_to_s3

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
