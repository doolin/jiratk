#!/usr/bin/env ruby

# frozen-string-literal: true

# TODO: `require '../lib/jiratk'` and have all these loaded in that file.
require_relative '../lib/jiratk/account_manager'
require_relative '../lib/jiratk/api_helper'
require_relative '../lib/jiratk/s3_tools'
require_relative '../lib/jiratk/project'

def account_manager
  @account_manager ||= AccountManager.new
end

api_keys = account_manager.api_keys
USERNAME = api_keys[:jira_id]
PASSWORD = api_keys[:jira_key]

# TODO: Create a "fake" project on Jira, prepopulate with fake issues in various
# states, then use that project with those issues to test the following:
#
# puts "issue count for GEN project: #{Project.issue_count_for('GEN')}"
# puts "list of keys for PLANTS project: #{Project.list_issues_for('PLANTS')}"
# Project.batch_download_for('PLANTS')

def write_all_issues_to_s3
  s3 = S3Tools.new

  account_manager.project_keys.each do |project|
    issues = Project.get_issues_for(project, 0)
    issues.each do |issue|
      s3.write(issue)
    end
  end
end
write_all_issues_to_s3
