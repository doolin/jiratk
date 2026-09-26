# frozen_string_literal: true

require_relative 'write_failure'

module JiraTk
  module Permissions
    # Executor binds these private methods to the same connection as discovery.
    module GrantTransport
      private

      def create_permission(step)
        response = permission_request(:post, permission_path(step), step.fetch('payload'))
        permission_status!(response, 201)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise WriteFailure.new('invalid_write_response'), cause: nil
      end

      def delete_permission(step)
        path = "#{permission_path(step)}/#{Validation.id(step.fetch('expected_grant').fetch('id'))}"
        response = permission_request(:delete, path)
        permission_status!(response, 204)
        nil
      end

      def permission_path(step)
        "/rest/api/3/permissionscheme/#{Validation.id(step.fetch('scheme_id'))}/permission"
      end

      def permission_request(method, path, payload = nil)
        if method == :post
          @api.post("#{@base_url}#{path}", payload, debug: false, bearer_token: @bearer_token)
        else
          @api.delete("#{@base_url}#{path}", bearer_token: @bearer_token)
        end
      rescue RestClient::Exception, SystemCallError, IOError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
        raise WriteFailure.new('write_transport_error'), cause: nil
      end

      def permission_status!(response, expected)
        return if response.code == expected

        raise WriteFailure.new('write_http_error', http_status: response.code)
      end
    end
  end
end
