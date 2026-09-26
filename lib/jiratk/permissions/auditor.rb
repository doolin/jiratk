# frozen_string_literal: true

require 'time'
require_relative 'client'
require_relative 'audit_scope'
require_relative 'audit_report'

module JiraTk
  module Permissions
    # Authenticate first; then query the target over the administrator's inventory.
    class Auditor
      def initialize(administrator:, audit_client:, expected_account_id:)
        @administrator = administrator
        @audit_client = audit_client
        @expected_account_id = Validation.text(expected_account_id)
      end

      def inspect
        "#<#{self.class}>"
      end

      def audit(projects: nil, positive: 'PAH', required_projects: AuditScope::BASELINE)
        scope = AuditScope.new(projects: projects, positive: positive, required: required_projects)
        identity = @administrator.verify_audit_identity(audit_client: @audit_client,
                                                        expected_account_id: @expected_account_id)
        inventory = scope.reconcile(@administrator.projects)
        rows = inventory.map { |row| row.merge('permissions' => permissions(row)) }
        AuditReport.new(identity: identity, scope: scope.to_h, rows: rows, timestamp: Time.now.utc.iso8601)
      end

      private

      def permissions(row)
        return PermissionCheck.unavailable(row['coverage']) unless row['coverage'] == 'audited'

        @audit_client.my_permissions(row['key'])
      end
    end
  end
end
