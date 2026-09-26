# frozen_string_literal: true

require 'json'
require 'uri'
require 'digest'
require_relative '../api_helper'
require_relative '../account_manager'
require_relative 'validation'

module JiraTk
  module Permissions
    # Read-only transport. Configuration is private; server links are never followed.
    class Connection
      def self.administrator(account_manager: AccountManager.new)
        keys = account_manager.api_keys
        username = Validation.credential(keys[:jira_id])
        password = Validation.credential(keys[:jira_key])
        new(base_url: account_manager.jira_url, api_helper: ApiHelper.new(username, password))
      end

      def self.service_account(base_url:, token:)
        new(base_url: base_url, api_helper: ApiHelper.new, bearer_token: Validation.text(token))
      end

      def initialize(base_url:, api_helper:, bearer_token: nil)
        @base_url = validated_url(base_url, gateway: true)
        @api = api_helper
        @bearer_token = bearer_token.nil? ? nil : Validation.credential(bearer_token)
      end

      def inspect
        "#<#{self.class}>"
      end

      def get(path, params = {})
        unless %r{\A/rest/api/3/[a-zA-Z0-9_/-]+\z}.match?(Validation.text(path))
          raise Error, 'Invalid Jira resource path'
        end

        response = @api.get("#{@base_url}#{path}", params, bearer_token: @bearer_token)
        raise Error, "Jira read failed (HTTP #{response.code})" unless response.code == 200

        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, 'Jira read returned invalid JSON', cause: nil
      rescue RestClient::Exception, SystemCallError, IOError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
        raise Error, 'Jira read failed at the transport boundary', cause: nil
      end

      def site_id
        info = Validation.object(get('/rest/api/3/serverInfo'))
        origin = validated_url(info['baseUrl'], gateway: false)
        if URI(@base_url).path.empty? && @base_url != origin
          raise Error, 'Jira site identity differs from the configured origin'
        end

        Digest::SHA256.hexdigest(origin)
      end

      private

      def validated_url(value, gateway:)
        uri = URI.parse(Validation.text(value))
        raise Error, 'Jira endpoint must be an HTTPS origin or approved gateway' unless safe_endpoint?(uri)

        path = uri.path.delete_suffix('/')
        raise Error, 'Unsupported Jira endpoint path' unless path.empty? || (gateway && gateway_path?(uri.host, path))

        uri.normalize.to_s.delete_suffix('/')
      rescue URI::InvalidURIError
        raise Error, 'Invalid Jira endpoint', cause: nil
      end

      def gateway_path?(host, path)
        uuid_path = %r{\A/ex/jira/[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z}
        host == 'api.atlassian.com' && uuid_path.match?(path)
      end

      def safe_endpoint?(uri)
        uri.is_a?(URI::HTTPS) && uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      end
    end
  end
end
