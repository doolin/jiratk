# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Reconcile discovered projects with required controls and an optional subset.
    class AuditScope
      BASELINE = %w[ADMIN BST DS FIN GEN PAH PLANT SCRUM TASKLETS].freeze

      def initialize(projects: nil, positive: 'PAH', required: BASELINE)
        @positive = Validation.project_key(positive)
        @required = (keys(required) + [@positive]).uniq.sort
        @requested = keys(projects) unless projects.nil?
        raise Error, 'Audit project selection cannot be empty' if @requested == []
      end

      def to_h
        { 'mode' => @requested.nil? ? 'all' : 'subset', 'requested_projects' => @requested,
          'required_projects' => @required, 'positive_project' => @positive }
      end

      def reconcile(projects)
        by_key = inventory_index(projects)
        (by_key.keys | @required | Array(@requested)).sort.map do |key|
          project = by_key.fetch(key) { missing(key) }
          project.merge('coverage' => coverage(project), 'new_project' => !@required.include?(key),
                        'expected' => key == @positive)
        end
      end

      private

      def inventory_index(projects)
        inventory = Validation.array(projects).map { |project| normalize(project) }
        Validation.unique(Validation.unique(inventory, 'id'), 'key')
        inventory.to_h { |project| [project['key'], project] }
      end

      def keys(values)
        values = Validation.array(values).map { |key| Validation.project_key(key) }
        raise Error, 'Duplicate audit project keys' unless values.uniq == values

        values.sort
      end

      def normalize(project)
        project = Validation.object(project)
        status = project['status']
        raise Error, 'Unsupported project status' unless %w[live archived deleted].include?(status)

        { 'id' => Validation.id(project['id']), 'key' => Validation.project_key(project['key']),
          'project_status' => status, 'style' => Validation.text(project['style']) }
      end

      def missing(key)
        { 'id' => nil, 'key' => key, 'project_status' => 'missing', 'style' => nil }
      end

      def coverage(project)
        return project['project_status'] unless project['project_status'] == 'live'
        return 'unsupported' unless project['style'] == 'classic'
        return 'not_selected' if @requested && !@requested.include?(project['key'])

        'audited'
      end
    end
  end
end
