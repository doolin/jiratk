# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Project-context results are evidence only when Jira returns explicit Booleans.
    class PermissionCheck
      KEYS = %w[BROWSE_PROJECTS CREATE_ISSUES EDIT_ISSUES TRANSITION_ISSUES ADD_COMMENTS ASSIGN_ISSUES].freeze

      def self.unavailable(reason)
        KEYS.to_h { |key| [key, { 'value' => nil, 'error' => reason }] }
      end

      def initialize(connection)
        @connection = connection
      end

      def for_project(project)
        read(Validation.project_key(project))
      end

      private

      def read(project)
        data = @connection.get('/rest/api/3/mypermissions', projectKey: project, permissions: KEYS.join(','))
        permissions = Validation.object(Validation.object(data)['permissions'])
        KEYS.to_h { |key| [key, cell(permissions[key], key)] }
      rescue Error
        self.class.unavailable('request_failed')
      end

      def cell(data, key)
        data = Validation.object(data)
        raise Error, 'Unexpected permission key' unless data['key'] == key

        { 'value' => Validation.boolean(data['havePermission']), 'error' => nil }
      rescue Error
        { 'value' => nil, 'error' => 'invalid_permission' }
      end
    end
  end
end
