# frozen-string-literal: true

require 'yaml'

# Add class documentation
class AccountManager
  def api_keys
    @api_keys ||= {
      jira_id: ENV['DOOLIN_JIRA_ID'],
      jira_key: ENV['DOOLIN_JIRA_API']
    }
  end

  def search_url
    @search_url ||= 'https://doolin.atlassian.net/rest/api/3/project/search'
  end

  def project_keys
    api_helper = ApiHelper.new(search_url)

    response = api_helper.get({})
    response_json = JSON.parse(response)

    response_json['values'].map { |value| value['key'] }
  end
end
