# frozen_string_literal: true

require 'json'

module JiraTk
  module Pah
    # Jira read client for Marisu — PAH issues only.
    class Client
      BASE_URL = 'https://doolin.atlassian.net'
      DEFAULT_FIELDS = 'summary,status,issuetype,components,parent,description'

      def initialize(api_helper: nil, allowed_project: nil)
        @allowed_project = allowed_project || Jql::PROJECT
        unless @allowed_project == 'PAH'
          raise Error, "Marisu client only supports PAH (got #{@allowed_project.inspect})"
        end

        @api = build_api(api_helper)
      end

      def get(issue_key, fields: DEFAULT_FIELDS)
        key = IssueKey.validate!(issue_key)
        url = "#{BASE_URL}/rest/api/3/issue/#{key}"
        check_response!(parse(@api.get(url, { fields: fields })))
      end

      def search(user_jql, max_results: 50, fields: DEFAULT_FIELDS)
        scoped = Jql.scope(user_jql)
        { 'jql' => scoped, 'issues' => fetch_search_issues(scoped, max_results, fields) }
      end

      private

      def build_api(api_helper)
        return api_helper if api_helper

        keys = AccountManager.new.api_keys
        validate_credentials!(keys)
        ApiHelper.new(keys[:jira_id], keys[:jira_key])
      end

      def fetch_search_issues(scoped, max_results, fields)
        issues = []
        token = nil
        loop do
          data = search_page(scoped, max_results, fields, token)
          issues.concat(data['issues'] || [])
          break if data['isLast']

          token = data['nextPageToken']
          break if token.nil? || token.empty?
        end
        issues
      end

      def search_page(scoped, max_results, fields, token)
        params = { jql: scoped, maxResults: max_results, fields: fields }
        params[:nextPageToken] = token if token
        check_response!(parse(@api.get("#{BASE_URL}/rest/api/3/search/jql", params)))
      end

      def validate_credentials!(keys)
        return if keys[:jira_id] && !keys[:jira_id].empty? && keys[:jira_key] && !keys[:jira_key].empty?

        raise Error,
              'Jira credentials missing. Set DOOLIN_JIRA_ID and DOOLIN_JIRA_API in the environment ' \
              'where marisu-jira runs (Cursor agent / shell profile).'
      end

      def check_response!(body)
        messages = body['errorMessages']
        if messages.is_a?(Array) && !messages.empty?
          hint = credentials_configured? ? messages.join('; ') : credential_hint
          raise Error, hint
        end

        body
      end

      def credentials_configured?
        keys = AccountManager.new.api_keys
        keys[:jira_id] && !keys[:jira_id].empty? && keys[:jira_key] && !keys[:jira_key].empty?
      end

      def credential_hint
        'Jira returned permission denied — usually missing DOOLIN_JIRA_ID / DOOLIN_JIRA_API ' \
          'in this shell. Export them where Marisu runs marisu-jira.'
      end

      def parse(response)
        JSON.parse(response.body)
      end
    end
  end
end
