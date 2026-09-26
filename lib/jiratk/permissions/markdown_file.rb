# frozen_string_literal: true

require 'tempfile'
require_relative 'audit_report'

module JiraTk
  module Permissions
    # Rename a complete, private temporary file over the last report on the same filesystem.
    class MarkdownFile
      DEFAULT_PATH = File.expand_path('../../../audit-results.md', __dir__).freeze

      def initialize(path: DEFAULT_PATH)
        @path = path
      end

      def save(report)
        content = render(report)
        Tempfile.create(['.jiratk-audit-', '.md'], File.dirname(@path)) do |file|
          file.write(content)
          file.flush
          file.fsync
          file.close
          File.rename(file.path, @path)
        end
      rescue SystemCallError, IOError
        raise Error, 'Unable to save audit evidence; previous report preserved', cause: nil
      end

      private

      def render(report)
        evidence = JSON.pretty_generate(report.to_h).gsub('`', '\\u0060')
        "# Jira permission audit\n\n```text\n#{report.matrix}\n```\n\n" \
          "## Evidence\n\n```json\n#{evidence}\n```\n"
      end
    end
  end
end
