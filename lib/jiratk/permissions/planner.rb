# frozen_string_literal: true

require_relative 'plan'
require_relative 'plan_snapshot'

module JiraTk
  module Permissions
    # Preparing and revalidating plans are strictly read-only operations.
    class Planner
      def initialize(administrator:, audit_client:)
        @snapshot = PlanSnapshot.new(administrator: administrator, audit_client: audit_client)
      end

      def inspect
        "#<#{self.class}>"
      end

      def pah_assign_repair(**expectations)
        prepare(RepairRequest.new(**expectations))
      end

      def revalidate(plan)
        raise Error, 'Expected a reviewed permission plan' unless plan.is_a?(Plan)

        fresh = prepare(RepairRequest.from_h(plan.request))
        unless fresh.preconditions == plan.preconditions
          raise Error,
                'Permission plan preconditions changed; review a new plan'
        end

        plan
      end

      private

      def prepare(request)
        Plan.new(request: request.to_h, evidence: @snapshot.capture(request))
      end
    end
  end
end
