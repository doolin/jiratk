# frozen_string_literal: true

require_relative '../jira_ticket'
require_relative 'description'

module JiraTk
  module Tickets
    # A plain Task payload using the existing ticket builder, without site-specific custom fields.
    class Task < ::JiraTicket
      Parameters = Data.define(:project_key, :issuetype_name)
      attr_reader :summary, :description

      def initialize(project:, summary:, text:, label:)
        raise Error, 'Invalid project key' unless /\A[A-Z][A-Z0-9_]*\z/.match?(project.to_s)
        raise Error, 'Use a unique lowercase task label' unless /\A[a-z0-9][a-z0-9_-]{0,254}\z/.match?(label.to_s)

        @summary = summary.to_s.strip
        raise Error, 'Summary must contain 1 to 255 characters' unless (1..255).cover?(@summary.length)

        super(Parameters.new(project_key: project, issuetype_name: 'Task'))
        @label = label
        @description = Description.new(nil).append(heading: 'Description', text: text)
      end

      def labels
        [@label]
      end

      def to_h
        { fields: super.fetch(:fields).slice(:project, :issuetype, :summary, :description, :labels) }
      end

      def search_jql
        %(project = "#{@project_key}" AND labels = "#{@label}")
      end

      def matches?(fields)
        fields['project'].is_a?(Hash) && fields['project']['key'] == @project_key &&
          fields['issuetype'].is_a?(Hash) && fields['issuetype'].slice('name', 'subtask') ==
            { 'name' => 'Task', 'subtask' => false } &&
          fields['summary'] == summary && fields['description'] == description && fields['labels'] == labels
      end
    end
  end
end
