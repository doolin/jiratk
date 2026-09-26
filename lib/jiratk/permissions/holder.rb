# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Resolve mutable group names; preserve named application roles distinctly.
    class Holder
      def initialize(client)
        @client = client
      end

      def normalize(data)
        data = Validation.object(data)
        type = Validation.text(data['type'])
        case type
        when 'group' then group(data)
        when 'projectRole' then role(data)
        when 'applicationRole' then { 'type' => type, 'id' => agreement(data), 'supported' => true }
        else
          { 'type' => type, 'id' => agreement(data), 'supported' => false }
        end
      end

      private

      def agreement(data)
        values = data.values_at('parameter', 'value').compact.uniq
        raise Error, 'Invalid Jira holder identity' unless values.all?(String)
        raise Error, 'Conflicting Jira holder identities' if values.length > 1

        values.first
      end

      def group(data)
        resolved = if data['value']
                     @client.group(id: Validation.text(data['value']))
                   else
                     @client.group(name: Validation.text(data['parameter']))
                   end
        if data['parameter'] && data['parameter'] != resolved['name']
          raise Error, 'Group name and immutable ID disagree'
        end

        { 'type' => 'group', 'id' => resolved['id'], 'name' => resolved['name'], 'supported' => true }
      end

      def role(data)
        ids = data.values_at('parameter', 'value').compact.map { |value| Validation.id(value) }.uniq
        raise Error, 'Missing or conflicting Jira role IDs' unless ids.length == 1

        resolved = @client.role(ids.first)
        { 'type' => 'projectRole', 'id' => resolved['id'], 'name' => resolved['name'], 'supported' => true,
          'protected' => resolved['id'] == '10003' || resolved['name'] == 'atlassian-addons-project-access' }
      end
    end
  end
end
