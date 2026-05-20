# frozen_string_literal: true

module JiraTk
  module Pah
    # Validates issue keys for Marisu (PAH-only reads).
    class IssueKey
      PATTERN = /\APAH-\d+\z/

      def self.valid?(key)
        key.is_a?(String) && key.match?(PATTERN)
      end

      def self.validate!(key)
        raise Error, "issue key must be PAH-<number>, got: #{key.inspect}" unless valid?(key)

        key
      end
    end
  end
end
