#!/usr/bin/env ruby

require 'pp'
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
  ticket_count = response_json['total']
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
project_list.each do |project|
  issues = get_issues_for(project)
  issues.each do |issue|
    s3.put_object(bucket: "inventium-jira", key: issue['key'], body: issue.to_json)
  end
end

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
=begin
plant_5 = {
  "expand": "operations,versionedRepresentations,editmeta,changelog,renderedFields",
  "id": "10005",
  "self": "https://doolin.atlassian.net/rest/api/3/issue/10005",
  "key": "PLANT-5",
  "fields": {
    "statuscategorychangedate": "2020-04-28T12:16:48.285-0700",
    "issuetype": {
      "self": "https://doolin.atlassian.net/rest/api/3/issuetype/10002",
      "id": "10002",
      "description": "A small, distinct piece of work.",
      "iconUrl": "https://doolin.atlassian.net/secure/viewavatar?size=medium&avatarId=10318&avatarType=issuetype",
      "name": "Task",
      "subtask": false,
      "avatarId": 10318
    },
    "timespent": 3600,
    "project": {
      "self": "https://doolin.atlassian.net/rest/api/3/project/10001",
      "id": "10001",
      "key": "PLANT",
      "name": "Plants",
      "projectTypeKey": "software",
      "simplified": false,
      "avatarUrls": {
        "48x48": "https://doolin.atlassian.net/secure/projectavatar?pid=10001&avatarId=10412",
        "24x24": "https://doolin.atlassian.net/secure/projectavatar?size=small&s=small&pid=10001&avatarId=10412",
        "16x16": "https://doolin.atlassian.net/secure/projectavatar?size=xsmall&s=xsmall&pid=10001&avatarId=10412",
        "32x32": "https://doolin.atlassian.net/secure/projectavatar?size=medium&s=medium&pid=10001&avatarId=10412"
      }
    },
    "fixVersions": [],
    "aggregatetimespent": 3600,
    "resolution": {
      "self": "https://doolin.atlassian.net/rest/api/3/resolution/10000",
      "id": "10000",
      "description": "Work has been completed on this issue.",
      "name": "Done"
    },
    "customfield_10027": null,
    "customfield_10028": null,
    "customfield_10029": null,
    "resolutiondate": "2020-04-28T12:16:48.279-0700",
    "workratio": -1,
    "watches": {
      "self": "https://doolin.atlassian.net/rest/api/3/issue/PLANT-5/watchers",
      "watchCount": 1,
      "isWatching": true
    },
    "lastViewed": "2020-09-12T08:51:09.331-0700",
    "created": "2020-04-28T04:40:26.171-0700",
    "customfield_10020": null,
    "customfield_10021": null,
    "customfield_10022": null,
    "priority": {
      "self": "https://doolin.atlassian.net/rest/api/3/priority/3",
      "iconUrl": "https://doolin.atlassian.net/images/icons/priorities/medium.svg",
      "name": "Medium",
      "id": "3"
    },
    "customfield_10023": "3_*:*_2_*:*_12470109_*|*_10002_*:*_1_*:*_7408635_*|*_10001_*:*_1_*:*_0_*|*_10003_*:*_1_*:*_7503390",
    "labels": [],
    "customfield_10016": null,
    "customfield_10017": null,
    "customfield_10018": {
      "hasEpicLinkFieldDependency": false,
      "showField": false,
      "nonEditableReason": {
        "reason": "PLUGIN_LICENSE_ERROR",
        "message": "The Parent Link is only available to Jira Premium users."
      }
    },
    "customfield_10019": "0|i00004:i",
    "aggregatetimeoriginalestimate": null,
    "timeestimate": 0,
    "versions": [],
    "issuelinks": [],
    "assignee": {
      "self": "https://doolin.atlassian.net/rest/api/3/user?accountId=557058%3A3f10cc1a-38d9-4261-9437-f42843f714c4",
      "accountId": "557058:3f10cc1a-38d9-4261-9437-f42843f714c4",
      "emailAddress": "david.doolin@gmail.com",
      "avatarUrls": {
        "48x48": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "24x24": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "16x16": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "32x32": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png"
      },
      "displayName": "David Doolin",
      "active": true,
      "timeZone": "America/Los_Angeles",
      "accountType": "atlassian"
    },
    "updated": "2020-09-12T08:51:09.122-0700",
    "status": {
      "self": "https://doolin.atlassian.net/rest/api/3/status/10001",
      "description": "",
      "iconUrl": "https://doolin.atlassian.net/",
      "name": "Done",
      "id": "10001",
      "statusCategory": {
        "self": "https://doolin.atlassian.net/rest/api/3/statuscategory/3",
        "id": 3,
        "key": "done",
        "colorName": "green",
        "name": "Done"
      }
    },
    "components": [],
    "timeoriginalestimate": null,
    "description": {
      "version": 1,
      "type": "doc",
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "This one is for Josh. I have a load of e. aureum cuttings from Margaret which need to be cleared off my table and counters, this is a great way to deal with that."
            }
          ]
        }
      ]
    },
    "customfield_10010": null,
    "customfield_10014": null,
    "customfield_10015": null,
    "customfield_10005": null,
    "customfield_10006": null,
    "security": null,
    "customfield_10007": null,
    "customfield_10008": null,
    "aggregatetimeestimate": 0,
    "customfield_10009": null,
    "summary": "Pot up all pothos cuttings into 8\" pot",
    "creator": {
      "self": "https://doolin.atlassian.net/rest/api/3/user?accountId=557058%3A3f10cc1a-38d9-4261-9437-f42843f714c4",
      "accountId": "557058:3f10cc1a-38d9-4261-9437-f42843f714c4",
      "emailAddress": "david.doolin@gmail.com",
      "avatarUrls": {
        "48x48": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "24x24": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "16x16": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "32x32": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png"
      },
      "displayName": "David Doolin",
      "active": true,
      "timeZone": "America/Los_Angeles",
      "accountType": "atlassian"
    },
    "subtasks": [],
    "reporter": {
      "self": "https://doolin.atlassian.net/rest/api/3/user?accountId=557058%3A3f10cc1a-38d9-4261-9437-f42843f714c4",
      "accountId": "557058:3f10cc1a-38d9-4261-9437-f42843f714c4",
      "emailAddress": "david.doolin@gmail.com",
      "avatarUrls": {
        "48x48": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "24x24": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "16x16": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png",
        "32x32": "https://secure.gravatar.com/avatar/19c322e5e942511e62cd0273f032a4c0?d=https%3A%2F%2Favatar-management--avatars.us-west-2.prod.public.atl-paas.net%2Finitials%2FDD-3.png"
      },
      "displayName": "David Doolin",
      "active": true,
      "timeZone": "America/Los_Angeles",
      "accountType": "atlassian"
    },
    "aggregateprogress": { "progress": 3600, "total": 3600, "percent": 100 },
    "customfield_10000": "{}",
    "customfield_10001": null,
    "customfield_10002": null,
    "customfield_10003": null,
    "customfield_10004": null,
    "environment": null,
    "duedate": null,
    "progress": { "progress": 3600, "total": 3600, "percent": 100 },
    "votes": {
      "self": "https://doolin.atlassian.net/rest/api/3/issue/PLANT-5/votes",
      "votes": 0,
      "hasVoted": false
    }
  }
}
=end
