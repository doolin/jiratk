# frozen_string_literal: true

require 'json'
require 'uri'
require_relative '../account_manager'
require_relative '../api_helper'
require_relative 'description'
require_relative 'task'

module JiraTk
  module Tickets
    # General ticket operations using JiraTK's existing authentication and HTTP helper.
    class Client
      FIELDS = %w[summary status parent description updated project issuetype labels].freeze

      def initialize(account_manager: AccountManager.new, api_helper: nil)
        @base_url = validated_url(account_manager.jira_url)
        @api = api_helper || build_api(account_manager)
      end

      def get(key)
        response = request(:get, issue_path(key), { fields: FIELDS.join(',') })
        raise Error, "Ticket read failed (HTTP #{response.code})" unless response.code == 200

        issue = JSON.parse(response.body)
        validate_issue!(issue, key)
        { 'key' => key, 'fields' => issue.fetch('fields').slice(*FIELDS) }
      rescue JSON::ParserError
        raise Error, 'Ticket read returned invalid JSON'
      end

      def append_description(key, heading:, text:, apply: false)
        before = get(key)
        current = before.fetch('fields').fetch('description')
        proposed = Description.new(current).append(heading: heading, text: text)
        return result(key, 'unchanged', proposed) if current == proposed
        return result(key, 'dry-run', proposed) unless apply == true

        raise Error, 'Ticket changed during preparation; read it again' unless get(key) == before

        apply_description(key, proposed)
        result(key, 'applied', proposed)
      end

      def create_task(project, summary:, text:, label:, apply: false)
        task = Task.new(project: project, summary: summary, text: text, label: label)
        key = existing_task(task)
        return verified_task(key, task, 'unchanged') if key
        return { 'status' => 'dry-run', 'payload' => task.to_h } unless apply == true

        response = request(:post, '/rest/api/3/issue', task.to_h, debug: false)
        body = response_json(response, 201)
        raise Error, 'Task creation returned no issue key; inspect before retrying' unless body['key'].is_a?(String)

        verified_task(body.fetch('key'), task, 'created')
      end

      private

      def result(key, status, description)
        { 'key' => key, 'status' => status, 'description' => description }
      end

      def apply_description(key, proposed)
        response = request(:put, issue_path(key), { fields: { description: proposed } })
        raise Error, "Ticket update failed (HTTP #{response.code}); inspect before retrying" unless response.code == 204

        return if get(key).fetch('fields').fetch('description') == proposed

        raise Error, 'Ticket update could not be verified; inspect before retrying'
      end

      def issue_path(key)
        raise Error, 'Invalid Jira issue key' unless /\A[A-Z][A-Z0-9_]*-[1-9]\d*\z/.match?(key.to_s)

        "/rest/api/3/issue/#{key}"
      end

      def request(method, path, payload, **options)
        @api.public_send(method, "#{@base_url}#{path}", payload, **options)
      rescue RestClient::Exception, SystemCallError, IOError, Timeout::Error, SocketError
        raise Error, 'Jira request failed; outcome may be unknown, inspect before retrying'
      end

      def existing_task(task)
        response = request(:get, '/rest/api/3/search/jql', { jql: task.search_jql, fields: 'key', maxResults: 2 })
        body = response_json(response, 200)
        issues = body['issues']
        unless body['isLast'] == true && issues.is_a?(Array) && issues.length <= 1
          raise Error, 'Task label search is incomplete or ambiguous; no task created'
        end
        return if issues.empty?

        key = issues.first.is_a?(Hash) && issues.first['key']
        raise Error, 'Task label search returned an invalid issue' unless key.is_a?(String)

        key
      end

      def verified_task(key, task, status)
        raise Error, 'Task identity or content differs; inspect before retrying' unless task.matches?(get(key)['fields'])

        { 'key' => key, 'status' => status }
      end

      def response_json(response, expected)
        unless response.code == expected
          raise Error, "Jira request failed (HTTP #{response.code}); inspect before retrying"
        end

        body = JSON.parse(response.body)
        raise Error, 'Jira returned an invalid response; inspect before retrying' unless body.is_a?(Hash)

        body
      rescue JSON::ParserError
        raise Error, 'Jira returned invalid JSON; inspect before retrying'
      end

      def validate_issue!(issue, key)
        raise Error, 'Ticket read returned an unexpected issue' unless issue.is_a?(Hash) && issue['key'] == key

        fields = issue['fields']
        return if fields.is_a?(Hash) && fields.key?('description') && fields['updated'].is_a?(String)

        raise Error, 'Ticket read omitted required fields'
      end

      def validated_url(value)
        uri = URI.parse(value.to_s)
        valid = uri.is_a?(URI::HTTPS) && uri.host && uri.userinfo.nil? &&
                site_origin?(uri)
        raise Error, 'Jira URL must be an HTTPS site origin' unless valid

        uri.to_s.delete_suffix('/')
      rescue URI::InvalidURIError
        raise Error, 'Jira URL must be an HTTPS site origin'
      end

      def site_origin?(uri)
        uri.query.nil? && uri.fragment.nil? && ['', '/'].include?(uri.path)
      end

      def build_api(account_manager)
        keys = account_manager.api_keys
        missing = [keys[:jira_id], keys[:jira_key]].any? { |value| value.to_s.strip.empty? }
        raise Error, 'Jira credentials are missing' if missing

        ApiHelper.new(keys[:jira_id], keys[:jira_key])
      end
    end
  end
end
