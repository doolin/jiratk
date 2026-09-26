# frozen_string_literal: true

require_relative '../jira_ticket'
require_relative 'description'

module JiraTk
  module Tickets
    # A plain Task payload using the existing ticket builder, without site-specific custom fields.
    class Task < ::JiraTicket
      Parameters = Data.define(:project_key, :issuetype_name)
      attr_reader :summary, :description, :parent

      def initialize(project:, summary:, text:, label:, parent: nil)
        raise Error, 'Invalid project key' unless /\A[A-Z][A-Z0-9_]*\z/.match?(project.to_s)
        raise Error, 'Use a unique lowercase task label' unless /\A[a-z0-9][a-z0-9_-]{0,254}\z/.match?(label.to_s)

        @summary = summary.to_s.strip
        raise Error, 'Summary must contain 1 to 255 characters' unless (1..255).cover?(@summary.length)

        @parent = parent
        validate_parent(project)
        super(Parameters.new(project_key: project, issuetype_name: parent ? 'Sub-task' : 'Task'))
        @label = label
        @description = Description.new(nil).append(heading: 'Description', text: text)
      end

      def labels
        [@label]
      end

      def to_h
        fields = super.fetch(:fields).slice(:project, :issuetype, :summary, :description, :labels)
        fields[:parent] = { key: parent } if parent
        { fields: fields }
      end

      def search_jql
        %(project = "#{@project_key}" AND labels = "#{@label}")
      end

      def matches?(fields)
        matching_project?(fields['project']) && matching_type?(fields['issuetype']) &&
          fields['summary'] == summary && fields['description'] == description && fields['labels'] == labels &&
          matching_parent?(fields['parent'])
      end

      private

      def matching_project?(data)
        data.is_a?(Hash) && data['key'] == @project_key
      end

      def matching_type?(data)
        data.is_a?(Hash) && data.slice('name', 'subtask') == { 'name' => @issuetype_name, 'subtask' => !parent.nil? }
      end

      def validate_parent(project)
        return if parent.nil?
        return if /\A#{Regexp.escape(project)}-[1-9]\d*\z/.match?(parent.to_s)

        raise Error, 'Parent must be an issue key in the same project'
      end

      def matching_parent?(data)
        return data.nil? unless parent

        data.is_a?(Hash) && data['key'] == parent
      end
    end
  end
end
