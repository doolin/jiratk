# frozen_string_literal: true

require 'forwardable'
require_relative 'connection'
require_relative 'directory'
require_relative 'pages'
require_relative 'scheme'
require_relative 'holder'
require_relative 'permission_check'

module JiraTk
  module Permissions
    # Read-only permission and membership discovery with separately injected identities.
    class Client
      extend Forwardable

      def_delegators :@directory, :group, :group_members, :account_groups, :role, :role_actors

      def initialize(connection:)
        @connection = connection
        @pages = Pages.new(connection)
        @holder = Holder.new(self)
        @directory = Directory.new(connection)
      end

      def inspect
        "#<#{self.class}>"
      end

      def identity
        user = Validation.account(@connection.get('/rest/api/3/myself'))
        raise Error, 'Jira authenticated account is inactive' unless user['active']

        user.merge('site_id' => @connection.site_id)
      end

      def verify_audit_identity(audit_client:, expected_account_id:)
        expected = Validation.text(expected_account_id)
        administrator = identity
        auditor = audit_client.identity
        unless auditor['id'] == expected && auditor['id'] != administrator['id'] &&
               auditor['site_id'] == administrator['site_id']
          raise Error, 'Audit account or Jira site identity differs'
        end

        auditor
      end

      def projects
        require_administrator!
        projects = %w[live archived deleted].flat_map { |status| project_page(status) }
        Validation.unique(Validation.unique(projects, 'id'), 'key')
      end

      def inventory
        associations = {}
        inventory = projects.map { |project| project_association(project, associations) }
        { 'projects' => inventory, 'scheme_projects' => associations }
      end

      def project_scheme(key)
        data = object_get("/rest/api/3/project/#{Validation.project_key(key)}/permissionscheme")
        Scheme.new(client: self, data: data)
      end

      def my_permissions(project)
        PermissionCheck.new(@connection).for_project(project)
      end

      def grants(scheme_id)
        data = object_get("/rest/api/3/permissionscheme/#{Validation.id(scheme_id)}/permission")
        grants = Validation.array(data['permissions']).map { |grant| normalize_grant(grant) }
        Validation.unique(grants, 'id')
      end

      def grant(scheme_id, grant_id)
        id = Validation.id(grant_id)
        data = object_get("/rest/api/3/permissionscheme/#{Validation.id(scheme_id)}/permission/#{id}")
        grant = normalize_grant(data)
        raise Error, 'Unexpected Jira grant ID' unless grant['id'] == id

        grant
      end

      private

      def object_get(path, params = {})
        Validation.object(@connection.get(path, params))
      end

      def require_administrator!
        permissions = object_get('/rest/api/3/mypermissions', permissions: 'ADMINISTER')
        permission = Validation.object(Validation.object(permissions['permissions'])['ADMINISTER'])
        raise Error, 'Complete project discovery requires Administer Jira' unless permission['havePermission'] == true
      end

      def project_page(status)
        @pages.read('/rest/api/3/project/search', status: status, orderBy: 'key').map do |data|
          data = Validation.object(data)
          { 'id' => Validation.id(data['id']), 'key' => Validation.project_key(data['key']),
            'name' => Validation.text(data['name']), 'style' => Validation.text(data['style']), 'status' => status }
        end
      end

      def normalize_grant(data)
        data = Validation.object(data)
        { 'id' => Validation.id(data['id']), 'permission' => Validation.text(data['permission']),
          'holder' => @holder.normalize(data['holder']) }
      end

      def project_association(project, associations)
        if project['style'] != 'classic' || project['status'] == 'deleted'
          return project.merge('scheme_id' => nil, 'coverage' => 'unsupported')
        end

        scheme = project_scheme(project['key'])
        (associations[scheme.id] ||= []) << project['key']
        project.merge('scheme_id' => scheme.id, 'coverage' => 'available')
      end
    end
  end
end
