# frozen_string_literal: true

require_relative 'pages'

module JiraTk
  module Permissions
    # Group and role membership reads used to establish the holders of grants.
    class Directory
      def initialize(connection)
        @connection = connection
        @pages = Pages.new(connection)
      end

      def group(id: nil, name: nil)
        query = group_query(id, name)
        groups = @pages.read('/rest/api/3/group/bulk', query).map { |data| normalize_group(data) }
        unless groups.length == 1 && group_matches?(groups.first, id, name)
          raise Error, 'Group identity is missing or ambiguous'
        end

        groups.first
      end

      def group_members(id)
        data = @pages.read('/rest/api/3/group/member', groupId: Validation.text(id), includeInactiveUsers: true)
        Validation.unique(data.map { |user| Validation.account(user) }, 'id')
      end

      def account_groups(account_id)
        data = @connection.get('/rest/api/3/user/groups', accountId: Validation.text(account_id))
        Validation.unique(Validation.array(data).map { |group| normalize_group(group) }, 'id')
      end

      def role(id)
        id = Validation.id(id)
        normalize_role(@connection.get("/rest/api/3/role/#{id}"), id)
      end

      def role_actors(project, role_id)
        id = Validation.id(role_id)
        data = Validation.object(@connection.get("/rest/api/3/project/#{Validation.project_key(project)}/role/#{id}"))
        role = normalize_role(data, id)
        actors = Validation.array(data['actors']).map { |actor| normalize_actor(actor) }
        role.merge('actors' => Validation.unique(actors, 'actor_id'))
      end

      private

      def group_query(id, name)
        raise Error, 'Provide one group ID or name' unless [id, name].compact.length == 1

        id ? { groupId: Validation.text(id) } : { groupName: Validation.text(name) }
      end

      def group_matches?(group, id, name)
        id ? group['id'] == id : group['name'] == name
      end

      def normalize_group(data)
        data = Validation.object(data)
        { 'id' => Validation.text(data['groupId']), 'name' => Validation.text(data['name']) }
      end

      def normalize_role(data, id)
        data = Validation.object(data)
        raise Error, 'Unexpected Jira role ID' unless Validation.id(data['id']) == id

        { 'id' => id, 'name' => Validation.text(data['name']) }
      end

      def normalize_actor(data)
        data = Validation.object(data)
        actor_id = Validation.id(data['id'])
        actor = case data['type']
                when 'atlassian-group-role-actor' then normalize_group(data['actorGroup']).merge('type' => 'group')
                when 'atlassian-user-role-actor' then user_actor(data['actorUser'])
                else raise Error, 'Unsupported Jira role actor'
                end
        actor.merge('actor_id' => actor_id)
      end

      def user_actor(data)
        user = Validation.object(data)
        { 'type' => 'user', 'id' => Validation.text(user['accountId']) }
      end
    end
  end
end
