# frozen_string_literal: true

require_relative 'markdown_file'

module JiraTk
  module Permissions
    # Storage adapters accept the existing report without changing audit collection.
    class Persistence
      def initialize(adapter: MarkdownFile.new)
        @adapter = adapter
      end

      def save(report)
        @adapter.save(report)
      end
    end
  end
end
