# frozen_string_literal: true

require_relative 'auditor'

module JiraTk
  module Permissions
    # Every capture starts new reads; no membership or grant cache spans captures.
    class PlanSnapshot
      def initialize(administrator:, audit_client:)
        @administrator = administrator
        @audit_client = audit_client
      end

      def inspect
        "#<#{self.class}>"
      end

      def capture(request)
        expected = request.to_h
        audit = collect_audit(expected['account_id'])
        inventory = @administrator.inventory['projects']
        roles = collect_roles(expected)
        { 'audit' => audit, 'inventory' => inventory,
          'project_roles' => roles }.merge(collect_resources(expected, roles))
      end

      private

      def collect_resources(expected, roles)
        scheme = @administrator.project_scheme('PAH')
        { 'scheme' => { 'id' => scheme.id, 'name' => scheme.name, 'grants' => scheme.grants },
          'role' => @administrator.role(expected['role']['id']),
          'groups' => collect_groups(expected, roles),
          'account_groups' => @administrator.account_groups(expected['account_id']) }
      end

      def collect_roles(expected)
        expected['scheme']['projects'].map do |key|
          @administrator.role_actors(key, expected['role']['id']).merge('project' => key)
        end
      end

      def collect_audit(account_id)
        report = Auditor.new(administrator: @administrator, audit_client: @audit_client,
                             expected_account_id: account_id).audit
        raise Error, 'Repair requires a complete permission audit' if report.status == 'incomplete'

        data = report.to_h
        projects = data['projects'].map do |entry|
          permissions = entry['permissions'].transform_values { |cell| cell['value'] }
          entry.slice('id', 'key').merge('permissions' => permissions)
        end
        data.slice('identity', 'timestamp').merge('projects' => projects)
      end

      def collect_groups(expected, roles)
        group_ids(expected, roles).map do |id|
          @administrator.group(id: id).merge('members' => @administrator.group_members(id))
        end
      end

      def group_ids(expected, roles)
        actors = roles.flat_map { |entry| entry['actors'] }.select { |actor| actor['type'] == 'group' }
        required = [expected['human_group']['id'], expected['service_group']['id']]
        (required + actors.map { |actor| actor['id'] }).uniq
      end
    end
  end
end
