# frozen_string_literal: true

require 'json'

module JiraTk
  module Pah
    # Jira client for Marisu — PAH issues only.
    # rubocop:disable Metrics/ClassLength
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

      def transitions(issue_key)
        key = IssueKey.validate!(issue_key)
        url = "#{BASE_URL}/rest/api/3/issue/#{key}/transitions"
        check_response!(parse(@api.get(url, {})))
      end

      def transition(issue_key, to:)
        target = to.to_s.strip
        raise Error, 'transition requires --to "<status name>"' if target.empty?

        match = resolve_transition(issue_key, target)
        apply_transition(issue_key, match)
      end

      def comment(issue_key, text:)
        body_text = text.to_s.strip
        raise Error, 'comment requires text' if body_text.empty?

        key = IssueKey.validate!(issue_key)
        url = "#{BASE_URL}/rest/api/3/issue/#{key}/comment"
        payload = { body: adf_paragraph(body_text) }
        response = @api.post(url, payload, debug: false)
        parse_post_success!(response)
      end

      private

      def adf_paragraph(text)
        {
          type: 'doc',
          version: 1,
          content: [
            {
              type: 'paragraph',
              content: [{ type: 'text', text: text }]
            }
          ]
        }
      end

      def parse_post_success!(response)
        code = response.code.to_i
        raise Error, parse_post_error(response) unless (200..299).cover?(code)

        body = response.body.to_s
        return {} if body.empty?

        check_response!(JSON.parse(body))
      end

      def resolve_transition(issue_key, target)
        data = transitions(issue_key)
        list = data['transitions'] || []
        match = find_transition(list, target)
        raise Error, unavailable_transition_message(target, list) unless match

        match
      end

      def apply_transition(issue_key, match)
        key = IssueKey.validate!(issue_key)
        url = "#{BASE_URL}/rest/api/3/issue/#{key}/transitions"
        payload = { transition: { id: match['id'] } }
        response = @api.post(url, payload, debug: false)
        check_transition_response!(response, key, match)
      end

      def find_transition(list, name)
        list.find { |t| t['name'].casecmp?(name) }
      end

      def unavailable_transition_message(name, list)
        available = list.map { |t| t['name'] }.join(', ')
        "No transition named #{name.inspect}. Available: #{available}"
      end

      def check_transition_response!(response, key, match)
        code = response.code.to_i
        raise Error, parse_post_error(response) unless (200..299).cover?(code)

        {
          'key' => key,
          'transition' => match['name'],
          'to' => match.dig('to', 'name')
        }
      end

      def parse_post_error(response)
        body = response.body.to_s
        return "Request failed (HTTP #{response.code})" if body.empty?

        parsed = JSON.parse(body)
        messages = parsed['errorMessages']
        return messages.join('; ') if messages.is_a?(Array) && !messages.empty?

        "Request failed (HTTP #{response.code})"
      rescue JSON::ParserError
        "Request failed (HTTP #{response.code})"
      end

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
    # rubocop:enable Metrics/ClassLength
  end
end
