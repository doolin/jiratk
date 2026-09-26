# frozen_string_literal: true

require_relative 'audit_scope'
require_relative 'permission_check'

module JiraTk
  module Permissions
    # Repair expectations preserve observed controls outside the affected permission.
    class RepairControls
      def initialize(request, evidence)
        @request = request
        @evidence = evidence
      end

      def verify!
        verify_identity!
        verify_inventory!
        unless before.fetch('PAH').values.all?(true) && before.fetch('GEN').except('ASSIGN_ISSUES').values.all?(false)
          raise Error, 'Initial PAH or GEN controls differ; review a broader repair'
        end
      end

      def before
        @evidence['audit']['projects'].to_h { |entry| [entry['key'], entry['permissions']] }
      end

      def after
        before.to_h { |key, permissions| [key, expected_permissions(key, permissions)] }
      end

      private

      def expected_permissions(key, permissions)
        return permissions if key == 'PAH' || !@request['scheme']['projects'].include?(key)

        permissions.merge('ASSIGN_ISSUES' => false)
      end

      def verify_identity!
        identity = @evidence['audit']['identity']
        raise Error, 'Plan audit identity differs' unless identity['active'] && identity['id'] == @request['account_id']

        unless @evidence['scheme'].slice('id', 'name') == @request['scheme'].slice('id', 'name') &&
               @evidence['role'] == @request['role']
          raise Error, 'Expected scheme or role identity differs'
        end
      end

      def verify_inventory!
        projects = @evidence['inventory']
        keys = projects.map { |entry| entry['key'] }
        complete = (AuditScope::BASELINE - keys).empty? && projects.all? do |entry|
          entry.values_at('status', 'style', 'coverage') == %w[live classic available]
        end
        raise Error, 'Repair requires complete supported project coverage' unless complete

        verify_associations!(projects)
      end

      def verify_associations!(projects)
        affected = affected_projects(projects)
        audited = @evidence['audit']['projects'].map { |entry| entry.slice('id', 'key') }
        discovered = projects.map { |entry| entry.slice('id', 'key') }
        return if affected == @request['scheme']['projects'] && discovered == audited

        raise Error, 'Project inventory or scheme associations differ'
      end

      def affected_projects(projects)
        projects.select { |entry| entry['scheme_id'] == @request['scheme']['id'] }.map { |entry| entry['key'] }
      end
    end
  end
end
