# frozen_string_literal: true

require_relative 'error'

module JiraTk
  module Tickets
    # Adds an identifiable section without rebuilding existing ADF nodes.
    class Description
      EMPTY = { 'type' => 'doc', 'version' => 1, 'content' => [].freeze }.freeze

      def initialize(document)
        @document = document.nil? ? EMPTY : document
        valid = @document.is_a?(Hash) && @document['type'] == 'doc' &&
                @document['version'] == 1 && @document['content'].is_a?(Array)
        raise Error, 'Unsupported ticket description format' unless valid
      end

      def append(heading:, text:)
        raise Error, 'Heading and section text must not be blank' if heading.strip.empty? || text.strip.empty?

        section = section_nodes(heading.strip, text)
        content = @document.fetch('content')
        matches = matching_headings(content, heading.strip)
        return @document.merge('content' => content + section) if matches.empty?
        return @document if matches.one? && existing_section(content, matches.first) == section

        raise Error, 'Section heading already exists with different or ambiguous content'
      end

      private

      def matching_headings(content, heading)
        content.each_index.select { |i| heading_text(content[i]) == heading }
      end

      def section_nodes(heading, text)
        title = { 'type' => 'heading', 'attrs' => { 'level' => 2 }, 'content' => [text_node(heading)] }
        paragraphs = text.strip.split(/\n\s*\n/).map do |paragraph|
          { 'type' => 'paragraph', 'content' => [text_node(paragraph.strip)] }
        end
        [title, *paragraphs]
      end

      def text_node(text)
        { 'type' => 'text', 'text' => text }
      end

      def heading_text(node)
        return unless node.is_a?(Hash) && node['type'] == 'heading'

        Array(node['content']).map { |child| child['text'] }.join
      end

      def existing_section(content, start)
        finish = ((start + 1)...content.length).find { |i| heading_text(content[i]) } || content.length
        content[start...finish]
      end
    end
  end
end
