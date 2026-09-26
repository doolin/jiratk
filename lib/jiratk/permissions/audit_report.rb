# frozen_string_literal: true

require 'json'
require_relative 'permission_check'

module JiraTk
  module Permissions
    # A report owns its evidence and serializes only normalized, non-secret fields.
    class AuditReport
      HEADERS = %w[PROJECT BROWSE CREATE EDIT TRANSITION COMMENT ASSIGN].freeze
      PROJECT_FIELDS = %w[id key project_status style coverage new_project expected].freeze
      SCOPE_FIELDS = %w[mode requested_projects required_projects positive_project].freeze

      def initialize(identity:, scope:, rows:, timestamp:)
        data = { 'identity' => identity.slice('id', 'active', 'site_id'), 'timestamp' => timestamp,
                 'permissions' => PermissionCheck::KEYS, 'scope' => scope.slice(*SCOPE_FIELDS),
                 'projects' => rows.map { |row| evidence(row) } }
        @data = JSON.parse(JSON.generate(data))
      end

      def to_h
        JSON.parse(JSON.generate(@data.merge('comparison' => comparison)))
      end

      def status
        return 'incomplete' unless complete?

        mismatches.empty? ? 'passed' : 'mismatch'
      end

      def exit_status
        { 'passed' => 0, 'mismatch' => 1, 'incomplete' => 2 }.fetch(status)
      end

      def matrix
        table = [HEADERS] + @data['projects'].map { |row| matrix_row(row) }
        lines = aligned_table(table)
        (lines + ['', "Result: #{status} (#{@data['scope']['mode']} scope)"]).join("\n")
      end

      private

      def aligned_table(table)
        widths = table.transpose.map { |column| column.map(&:length).max }
        table.map do |row|
          row.each_with_index.map { |cell, index| cell.ljust(widths[index]) }.join('  ').rstrip
        end
      end

      def evidence(row)
        permissions = PermissionCheck::KEYS.to_h do |key|
          cell = row.fetch('permissions').fetch(key)
          [key, cell.slice('value', 'error')]
        end
        row.slice(*PROJECT_FIELDS).merge('permissions' => permissions)
      end

      def matrix_row(row)
        [row['key']] + PermissionCheck::KEYS.map do |key|
          value = row['permissions'][key]['value']
          value.nil? ? 'unknown' : value.to_s
        end
      end

      def complete?
        @data['scope']['mode'] == 'all' && !@data['projects'].empty? &&
          @data['projects'].all? { |row| row['coverage'] == 'audited' } && unknowns.empty?
      end

      def comparison
        { 'status' => status, 'mismatches' => mismatches, 'unknowns' => unknowns,
          'coverage_gaps' => coverage_gaps }
      end

      def coverage_gaps
        @data['projects'].reject { |row| row['coverage'] == 'audited' }.map { |row| row.slice('key', 'coverage') }
      end

      def mismatches
        cells.filter_map do |row, key, cell|
          next if cell['value'].nil? || cell['value'] == row['expected']

          { 'project' => row['key'], 'permission' => key, 'expected' => row['expected'], 'actual' => cell['value'] }
        end
      end

      def unknowns
        cells.filter_map do |row, key, cell|
          { 'project' => row['key'], 'permission' => key, 'error' => cell['error'] } if cell['value'].nil?
        end
      end

      def cells
        @data['projects'].flat_map do |row|
          PermissionCheck::KEYS.map { |key| [row, key, row['permissions'][key]] }
        end
      end
    end
  end
end
