# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Prove the intended PAH group path and exclude every shared negative role.
    class RepairMembership
      def initialize(request, evidence)
        @request = request
        @groups = evidence.fetch('groups')
        @groups_by_id = @groups.to_h { |entry| [entry['id'], entry] }
        @account_groups = evidence.fetch('account_groups')
        @roles = evidence.fetch('project_roles')
      end

      def verify!
        verify_role_scope!
        verify_group_scope!
        %w[human_group service_group].each { |key| verify_group!(@request.fetch(key)) }
        @groups.each { |entry| verify_account_membership!(entry) }
        verify_target_groups!
        @roles.each { |entry| verify_actors!(entry) }
      end

      private

      def verify_target_groups!
        return if member?(group(@request['service_group']['id'])) && !member?(group(@request['human_group']['id']))

        raise Error, 'Service-account group membership differs'
      end

      def group(id)
        @groups_by_id.fetch(id)
      end

      def member?(entry)
        entry['members'].any? { |user| user['id'] == @request['account_id'] && user['active'] }
      end

      def verify_group!(expected)
        raise Error, 'Group identity differs' unless group(expected['id']).slice('id', 'name') == expected
      end

      def verify_role_scope!
        unless @roles.map { |entry| entry['project'] } == @request['scheme']['projects'] &&
               @roles.all? { |entry| entry.slice('id', 'name') == @request['role'] }
          raise Error, 'Shared project role identities differ'
        end
      end

      def group_actors(entry)
        entry['actors'].select { |actor| actor['type'] == 'group' }
      end

      def verify_group_scope!
        ids = @roles.flat_map { |entry| group_actors(entry) }.map { |actor| actor['id'] }
        expected = (ids + [@request['human_group']['id'], @request['service_group']['id']]).uniq.sort
        raise Error, 'Relevant group inventory differs' unless @groups.map { |entry| entry['id'] } == expected
      end

      def verify_account_membership!(entry)
        listed = @account_groups.find { |item| item['id'] == entry['id'] }
        member = entry['members'].find { |user| user['id'] == @request['account_id'] }
        valid = member ? member['active'] && listed == entry.slice('id', 'name') : listed.nil?
        raise Error, 'Account and group membership evidence disagree' unless valid
      end

      def verify_actors!(entry)
        group_actors(entry).each { |actor| verify_group!(actor.slice('id', 'name')) }
        if entry['project'] == 'PAH'
          verify_pah_actor!(entry)
        elsif entry['actors'].any? { |actor| target_actor?(actor) }
          raise Error, 'Service account holds Ticket Manager in a negative-control project'
        end
      end

      def verify_pah_actor!(entry)
        return if group_actors(entry).any? { |actor| actor['id'] == @request['service_group']['id'] }

        raise Error, 'PAH Ticket Manager lacks the intended service group'
      end

      def target_actor?(actor)
        actor['type'] == 'user' ? actor['id'] == @request['account_id'] : member?(group(actor['id']))
      end
    end
  end
end
