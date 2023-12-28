#!/usr/bin/env ruby

# frozen_string_literal: true

require 'runbook'
require_relative '../lib/jiratk'
require_relative '../lib/jiratk/issue'

# Subclass to reduce cognitive load
class GemIssue < Issue
  def summary
    "update #{@gem} gem to version #{@version}"
  end

  def labels
    ['maintenance']
  end

  def description
    'updating a ruby gem'
  end
end

require 'ostruct'

# rubocop:disable Metrics/BlockLength
runbook = Runbook.book 'Update gem' do
  # TODO: add setup section for instantiating ApiHelper

  section 'collect gem information' do
    step 'collect project name' do
      ask 'what project?', into: :project
      ask 'what gem?', into: :gem
      ask 'what version?', into: :version
      ruby_command do
        confirm "project name #{project}?"
        confirm "gem name #{gem}?"
        confirm "version number #{version}?"
      end
    end

    step 'load up the struct' do
      ruby_command do
        ticket = OpenStruct.new(project_key: project, # rubocop:disable Style/OpenStructUse
                                issuetype_name: 'Task',
                                gem:,
                                version:)
        params = GemIssue.new(ticket).to_h
        confirm "Gem update parameters: #{params}"

        api_keys = AccountManager.new.api_keys
        username = api_keys[:jira_id]
        password = api_keys[:jira_key]
        api_helper = ApiHelper.new(username, password)
        api_url = 'https://doolin.atlassian.net/rest/api/2/issue/'

        api_helper.post(api_url, params)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength

if __FILE__ == $PROGRAM_NAME
  Runbook::Runner.new(runbook).run
else
  runbook
end
