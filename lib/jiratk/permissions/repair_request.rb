# frozen_string_literal: true

require_relative 'plan_data'

module JiraTk
  module Permissions
    # The initial repair has a deliberately narrow, explicit set of expectations.
    class RepairRequest
      HUMAN_GROUP_ID = 'fc8e7ac7-be76-4f1b-b481-6221f06b20a8'

      def initialize(account_id:, service_group_id:, broad_holder_id:, projects: %w[GEN PAH])
        @account_id = Validation.text(account_id)
        @service_group_id = Validation.text(service_group_id)
        @broad_holder_id = broad_holder_id
        @projects = Validation.array(projects).map { |key| Validation.project_key(key) }.sort
        validate!
        @data = PlanData.copy(expectations)
      end

      def self.from_h(data)
        data = Validation.object(data)
        group = Validation.object(data['service_group'])
        holder = Validation.object(Validation.object(data['broad_grant'])['holder'])
        new(account_id: data.fetch('account_id'), service_group_id: group.fetch('id'),
            broad_holder_id: holder.fetch('id'), projects: Validation.object(data['scheme']).fetch('projects'))
      end

      def to_h
        PlanData.copy(@data)
      end

      private

      def validate!
        unless @broad_holder_id.nil? || @broad_holder_id.is_a?(String)
          raise Error, 'An explicit application-role identity is required'
        end
        unless @projects.uniq == @projects && (%w[GEN PAH] - @projects).empty?
          raise Error, 'Repair scope must include GEN and PAH without duplicate projects'
        end
        raise Error, 'Service and human groups must differ' if @service_group_id == HUMAN_GROUP_ID
      end

      def expectations
        { 'operation' => 'pah_assign_repair', 'account_id' => @account_id,
          'service_group' => { 'id' => @service_group_id, 'name' => 'pah-ticket-managers' },
          'human_group' => { 'id' => HUMAN_GROUP_ID, 'name' => 'jira-project-users' },
          'role' => { 'id' => '10076', 'name' => 'Ticket Manager' },
          'scheme' => { 'id' => '10003', 'name' => 'GEN software permission scheme', 'projects' => @projects },
          'broad_grant' => { 'id' => '10592', 'permission' => 'ASSIGN_ISSUES',
                             'holder' => { 'type' => 'applicationRole', 'id' => @broad_holder_id,
                                           'supported' => true } },
          'protected_grant' => { 'id' => '10532', 'permission' => 'ASSIGN_ISSUES',
                                 'holder' => { 'type' => 'projectRole', 'id' => '10003',
                                               'name' => 'atlassian-addons-project-access',
                                               'supported' => true, 'protected' => true } } }
      end
    end
  end
end
