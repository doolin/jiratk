# frozen_string_literal: true

require_relative 'plan_data'
require_relative 'permission_check'

module JiraTk
  module Permissions
    # Normalize only fields needed to review and revalidate the initial repair.
    class PlanEvidence
      def initialize(data)
        data = Validation.object(data)
        @data = { 'audit' => audit(data.fetch('audit')), 'inventory' => inventory(data.fetch('inventory')),
                  'scheme' => scheme(data.fetch('scheme')), 'role' => role(data.fetch('role')),
                  'project_roles' => project_roles(data.fetch('project_roles')),
                  'groups' => groups(data.fetch('groups')),
                  'account_groups' => group_list(data.fetch('account_groups')) }
      end

      def to_h
        PlanData.copy(@data)
      end

      private

      def audit(data)
        data = Validation.object(data)
        identity = Validation.object(data.fetch('identity'))
        site = Validation.text(identity['site_id'])
        raise Error, 'Invalid Jira site fingerprint' unless /\A[0-9a-f]{64}\z/.match?(site)

        { 'identity' => { 'id' => Validation.text(identity['id']),
                          'active' => Validation.boolean(identity['active']), 'site_id' => site },
          'timestamp' => PlanData.timestamp(data['timestamp']), 'projects' => audit_projects(data['projects']) }
      end

      def audit_projects(data)
        PlanData.records(data, 'key') do |project|
          permissions = Validation.object(project['permissions'])
          values = PermissionCheck::KEYS.to_h { |key| [key, Validation.boolean(permissions[key])] }
          { 'id' => Validation.id(project['id']), 'key' => Validation.project_key(project['key']),
            'permissions' => values }
        end
      end

      def inventory(data)
        projects = PlanData.records(data, 'key') do |project|
          { 'id' => Validation.id(project['id']), 'key' => Validation.project_key(project['key']),
            'status' => Validation.text(project['status']), 'style' => Validation.text(project['style']),
            'scheme_id' => Validation.id(project['scheme_id']), 'coverage' => Validation.text(project['coverage']) }
        end
        Validation.unique(projects, 'id')
      end

      def scheme(data)
        data = Validation.object(data)
        { 'id' => Validation.id(data['id']), 'name' => Validation.text(data['name']),
          'grants' => PlanData.records(data['grants'], 'id') { |item| grant(item) } }
      end

      def grant(data)
        { 'id' => Validation.id(data['id']), 'permission' => Validation.text(data['permission']),
          'holder' => holder(Validation.object(data['holder'])) }
      end

      def holder(data)
        type = Validation.text(data['type'])
        case type
        when 'group' then group(data).merge('type' => type, 'supported' => true)
        when 'projectRole'
          protected_role = data['id'].to_s == '10003' || data['name'] == 'atlassian-addons-project-access'
          role(data).merge('type' => type, 'supported' => true, 'protected' => protected_role)
        else opaque_holder(type, data['id'])
        end
      end

      def opaque_holder(type, id)
        raise Error, 'Invalid Jira holder identity' unless id.nil? || id.is_a?(String)

        { 'type' => type, 'id' => id, 'supported' => type == 'applicationRole' }
      end

      def role(data)
        data = Validation.object(data)
        { 'id' => Validation.id(data['id']), 'name' => Validation.text(data['name']) }
      end

      def project_roles(data)
        PlanData.records(data, 'project') do |entry|
          role(entry).merge('project' => Validation.project_key(entry['project']),
                            'actors' => PlanData.records(entry['actors'], 'actor_id') { |item| actor(item) })
        end
      end

      def actor(data)
        identity = case data['type']
                   when 'group' then group(data)
                   when 'user' then { 'id' => Validation.text(data['id']) }
                   else raise Error, 'Unsupported Jira role actor'
                   end
        identity.merge('actor_id' => Validation.id(data['actor_id']), 'type' => data['type'])
      end

      def group(data)
        { 'id' => Validation.text(data['id']), 'name' => Validation.text(data['name']) }
      end

      def group_list(data)
        PlanData.records(data, 'id') { |item| group(item) }
      end

      def groups(data)
        PlanData.records(data, 'id') do |entry|
          members = PlanData.records(entry['members'], 'id') do |member|
            { 'id' => Validation.text(member['id']), 'active' => Validation.boolean(member['active']) }
          end
          group(entry).merge('members' => members)
        end
      end
    end
  end
end
