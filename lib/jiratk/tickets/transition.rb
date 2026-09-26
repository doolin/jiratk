# frozen_string_literal: true

require_relative 'error'

module JiraTk
  module Tickets
    # Allowlisted workflow metadata; transition names and destination names differ.
    class Transition
      def self.identity(value)
        valid = value.is_a?(Hash) && value['id'].is_a?(String) && /\A[1-9]\d*\z/.match?(value['id']) &&
                value['name'].is_a?(String) && !value['name'].strip.empty?
        raise Error, 'Jira returned invalid workflow identity metadata' unless valid

        value.slice('id', 'name')
      end

      def initialize(data)
        @identity = self.class.identity(data)
        @destination = self.class.identity(data['to'])
        @screen = boolean(data['hasScreen'])
        @available = boolean(data.fetch('isAvailable', true))
        @required = required_fields(data['fields'])
      end

      def to_h
        @identity.merge('to' => @destination, 'has_screen' => @screen,
                        'available' => @available, 'required_fields' => @required)
      end

      def self.select(options, target)
        matches = options.select { |option| option.fetch('to').fetch('name') == target }
        raise Error, 'Destination is unavailable or ambiguous; list transitions first' unless matches.length == 1

        selected = matches.first
        unless selected.fetch('available') && selected.fetch('required_fields').empty?
          raise Error, 'Transition is unavailable or requires fields; use Jira to complete it'
        end

        selected
      end

      private

      def boolean(value)
        raise Error, 'Jira returned invalid workflow flags' unless [true, false].include?(value)

        value
      end

      def required_fields(fields)
        raise Error, 'Jira omitted transition field metadata' unless fields.is_a?(Hash)

        fields.select do |_name, metadata|
          raise Error, 'Jira returned invalid transition field metadata' unless metadata.is_a?(Hash)

          boolean(metadata['required'])
        end.keys.sort
      end
    end
  end
end
