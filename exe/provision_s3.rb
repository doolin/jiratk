#!/usr/bin/env ruby

# frozen-string-literal: true

require_relative '../lib/jiratk'

def account_manager
  @account_manager ||= AccountManager.new
end

api_keys = account_manager.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]

# TODO: Create a "fake" project on Jira, prepopulate with fake issues in various
# states, then use that project with those issues to test the following:
# puts "issue count for GEN project: #{Project.issue_count_for('GEN')}"
# Project.batch_download_for('PLANTS')
# exit

def write_all_issues_to_s3
  writer = S3Tools.new.method(:write)

  account_manager.project_keys.each do |project|
    Project.batch_download_for(project, writer)
  end
end
write_all_issues_to_s3
