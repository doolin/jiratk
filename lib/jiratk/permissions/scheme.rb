# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # A scheme reference; grants are fetched afresh, never cached across a preflight.
    class Scheme
      attr_reader :id, :name

      def initialize(client:, data:)
        @client = client
        data = Validation.object(data)
        @id = Validation.id(data['id'])
        @name = Validation.text(data['name'])
      end

      def inspect
        "#<#{self.class} id=#{id}>"
      end

      def grants
        @client.grants(id)
      end

      def find(permission:, holder_type:, holder_id:)
        identity = holder_id&.to_s
        grants.select do |grant|
          grant['permission'] == permission && grant['holder']['type'] == holder_type &&
            grant['holder']['id'] == identity
        end
      end
    end
  end
end
