# frozen_string_literal: true

require_relative 'permission_check'

module JiraTk
  module Permissions
    # Derive exact additions and removal from a complete, normalized scheme read.
    class RepairGrants
      def initialize(request, evidence)
        @request = request
        @grants = evidence.fetch('scheme').fetch('grants')
      end

      def verify!
        raise Error, 'Expected protected addon grant differs' unless @grants.include?(@request['protected_grant'])

        (PermissionCheck::KEYS - ['ASSIGN_ISSUES']).each do |permission|
          raise Error, 'Ticket Manager is missing another PAH permission' unless match(permission, holders.first)
        end
        verify_deletion!
      end

      def replacements
        holders.map do |holder|
          existing = match('ASSIGN_ISSUES', holder)
          { 'action' => existing ? 'noop' : 'add', 'scheme_id' => @request['scheme']['id'],
            'grant_id' => existing&.fetch('id'),
            'payload' => { 'permission' => 'ASSIGN_ISSUES',
                           'holder' => { 'type' => holder['type'], 'value' => holder['id'] } } }
        end
      end

      def deletion
        { 'action' => target ? 'delete' : 'noop', 'scheme_id' => @request['scheme']['id'],
          'expected_grant' => @request['broad_grant'] }
      end

      def protected_grants
        @grants.select { |grant| grant['holder']['protected'] }
      end

      def projected
        after_additions.reject { |grant| grant['id'] == @request['broad_grant']['id'] }
      end

      def after_additions
        additions = holders.reject { |holder| match('ASSIGN_ISSUES', holder) }.map do |holder|
          { 'id' => nil, 'permission' => 'ASSIGN_ISSUES', 'holder' => holder }
        end
        (@grants + additions).sort_by { |grant| sort_key(grant) }
      end

      def target
        @grants.find { |grant| grant['id'] == @request['broad_grant']['id'] }
      end

      private

      def sort_key(grant)
        [grant['permission'], grant['holder']['type'], grant['holder']['id'].to_s, grant['id'].to_s]
      end

      def holders
        [@request['role'].merge('type' => 'projectRole', 'supported' => true, 'protected' => false),
         @request['human_group'].merge('type' => 'group', 'supported' => true)]
      end

      def match(permission, holder)
        candidates = @grants.select do |grant|
          grant['permission'] == permission && grant['holder'].slice('type', 'id') == holder.slice('type', 'id')
        end
        if candidates.length > 1 || candidates.any? { |grant| grant['holder'] != holder }
          raise Error, 'Required grant is ambiguous or its holder differs'
        end

        candidates.first
      end

      def verify_deletion!
        expected = @request['broad_grant']
        raise Error, 'Deletion target differs from the expected broad grant' if target && target != expected

        equivalent = match(expected['permission'], expected['holder'])
        raise Error, 'Broad grant identity differs' unless equivalent == target
        return if target || replacements.all? { |step| step['action'] == 'noop' }

        raise Error, 'Absent broad grant lacks verified replacements'
      end
    end
  end
end
