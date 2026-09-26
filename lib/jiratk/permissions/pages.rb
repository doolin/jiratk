# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Offset pagination with an explicit completeness contract, including empty lists.
    class Pages
      def initialize(connection)
        @connection = connection
      end

      def read(path, params = {})
        values = []
        total = nil
        loop do
          page = read_page(path, params, values.length)
          total ||= page['total']
          raise Error, 'Jira pagination total changed; repeat discovery' unless total == page['total']

          values.concat(page['values'])
          return values if page['isLast']
        end
      end

      private

      def read_page(path, params, offset)
        page = Validation.object(@connection.get(path, params.merge(startAt: offset, maxResults: 50)))
        items = Validation.array(page['values'])
        validate_offset(page['startAt'], offset)
        validate_size(page, items.length, offset)
        validate_completion(page, items, offset)
        page
      end

      def validate_offset(actual, expected)
        raise Error, 'Invalid Jira pagination offset' unless actual.is_a?(Integer) && actual == expected
      end

      def validate_size(page, length, offset)
        limit = page['maxResults']
        total = page['total']
        valid = limit.is_a?(Integer) && limit.positive? && length <= limit &&
                total.is_a?(Integer) && total >= offset + length
        raise Error, 'Invalid Jira pagination metadata' unless valid
      end

      def validate_completion(page, items, offset)
        last = Validation.boolean(page['isLast'])
        raise Error, 'Incomplete Jira pagination' unless last == (offset + items.length == page['total'])
        raise Error, 'Jira pagination did not advance' if !last && items.empty?
      end
    end
  end
end
