# frozen_string_literal: true

require 'json'
require 'digest'
require 'time'
require_relative 'validation'

module JiraTk
  module Permissions
    # Canonical data, not connection objects, crosses the saved-plan boundary.
    module PlanData
      module_function

      def copy(value)
        JSON.parse(JSON.generate(value))
      end

      def canonical(value)
        case value
        when Hash then value.sort.to_h.transform_values { |item| canonical(item) }
        when Array then value.map { |item| canonical(item) }
        else value
        end
      end

      def digest(value)
        Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
      end

      def timestamp(value)
        Time.iso8601(Validation.text(value)).utc.iso8601
      rescue ArgumentError
        raise Error, 'Invalid plan timestamp', cause: nil
      end

      def records(value, key)
        items = Validation.array(value).map { |item| yield Validation.object(item) }
        Validation.unique(items, key).sort_by { |item| item.fetch(key) }
      end
    end
  end
end
