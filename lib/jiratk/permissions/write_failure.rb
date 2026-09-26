# frozen_string_literal: true

require_relative 'validation'

module JiraTk
  module Permissions
    # Only a category and HTTP status cross the mutation error boundary.
    class WriteFailure < Error
      def initialize(category, http_status: nil)
        super('Permission write failed; inspect execution evidence before retrying')
        @category = category
        @http_status = http_status
      end

      def details
        { 'category' => @category, 'http_status' => @http_status }
      end

      def rejected?
        [400, 401, 403, 404, 409, 422, 429].include?(@http_status)
      end
    end
  end
end
