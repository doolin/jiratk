#!/usr/bin/env ruby

# frozen-string-literal: true

require_relative '../lib/jiratk'

def account_manager
  @account_manager ||= AccountManager.new
end

api_keys = account_manager.api_keys
username = api_keys[:jira_id]
password = api_keys[:jira_key]
@api_helper = ApiHelper.new(username, password)

# TODO: Create a "fake" project on Jira, prepopulate with fake issues in various
# states: https://doolin.atlassian.net/browse/GEN-83
# Then use that project with those issues to test the following:
# puts "issue count for GEN project: #{Project.issue_count_for(@api_helper, 'GEN')}"
# Project.batch_download_for(@api_helper, 'PLANTS')
# exit

def write_all_issues_to_s3
  writer = S3Tools.new.method(:write)

  account_manager.project_keys(@api_helper).each do |project|
    Project.batch_download_for(@api_helper, project, writer)
  end
end
write_all_issues_to_s3
