# frozen-string-literal: true

require_relative './jira_ticket'

# Subclass to reduce cognitive load
class AssessmentTicket < JiraTicket
  def initialize(params)
    @url = params.url
    @name = params.name
    super
  end

  def summary
    "The #{@name} assessment"
  end

  def labels
    ['maintenance']
  end

  def description
    "Link to spreadsheet: #{@url}"
  end
end
