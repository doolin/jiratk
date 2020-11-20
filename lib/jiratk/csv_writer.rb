# frozen-string-literal: true

# Utilities for writing CSV files
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
class CsvWriter
  def new; end
end
