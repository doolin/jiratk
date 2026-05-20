# frozen_string_literal: true

module JiraTk
  module Pah
    # Scopes JQL to the allowed project (PAH).
    class Jql
      PROJECT = ENV.fetch('JIRATK_ALLOWED_PROJECT', 'PAH').freeze

      class << self
        def scope(user_jql)
          fragment = user_jql.to_s.strip
          raise Error, 'JQL must not reference projects other than PAH' if references_other_project?(fragment)

          return "project = #{PROJECT}" if fragment.empty?
          return "project = #{PROJECT} #{fragment}" if order_by_only?(fragment)

          "project = #{PROJECT} AND (#{fragment})"
        end

        def order_by_only?(jql)
          jql.match?(/\AORDER\s+BY\b/i)
        end

        def references_other_project?(jql)
          return false if jql.empty?

          jql.match?(/\bproject\s*!=/i) ||
            jql.match?(/\bproject\s*(?:not\s+)?in\s*\(/i) ||
            jql.match?(/\bproject\s*=\s*["']?(?!#{PROJECT}\b)/i)
        end
      end
    end
  end
end
