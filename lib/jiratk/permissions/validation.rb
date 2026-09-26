# frozen_string_literal: true

module JiraTk
  module Permissions
    class Error < StandardError; end

    # Validate external data without including it in exception messages.
    module Validation
      module_function

      def object(value)
        raise Error, 'Expected a Jira object' unless value.is_a?(Hash)

        value
      end

      def array(value)
        raise Error, 'Expected a complete Jira list' unless value.is_a?(Array)

        value
      end

      def text(value)
        raise Error, 'Expected a nonblank Jira string' unless value.is_a?(String) && !value.strip.empty?

        value
      end

      def id(value)
        value = value.to_s if value.is_a?(Integer)
        raise Error, 'Expected a numeric Jira ID' unless /\A[1-9]\d*\z/.match?(text(value))

        value
      end

      def credential(value)
        value = text(value)
        raise Error, 'Invalid Jira credential' if /[[:space:][:cntrl:]]/.match?(value)

        value
      end

      def project_key(key)
        raise Error, 'Invalid Jira project key' unless /\A[A-Z][A-Z0-9_]*\z/.match?(text(key))

        key
      end

      def account(data)
        data = object(data)
        { 'id' => text(data['accountId']), 'active' => boolean(data['active']) }
      end

      def boolean(value)
        raise Error, 'Expected a Jira Boolean' unless [true, false].include?(value)

        value
      end

      def unique(values, key)
        ids = values.map { |value| value.fetch(key) }
        raise Error, 'Duplicate Jira identities; discovery is inconsistent' unless ids.uniq == ids

        values
      end
    end
  end
end
