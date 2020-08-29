require 'yaml'

class AccountManager
  def api_keys
      @api_keys ||= {
        jira_id: ENV['DOOLIN_JIRA_ID'],
        jira_key: ENV['DOOLIN_JIRA_API']
      }
  end
end