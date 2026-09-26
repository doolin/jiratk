# frozen_string_literal: true

require_relative 'client'
require_relative 'plan_snapshot'
require_relative 'execution_run'
require_relative 'readback'

module JiraTk
  module Permissions
    # Explicit apply is the sole public grant mutation boundary.
    class Executor
      def initialize(administrator_connection:, audit_client:, verification_attempts: 3,
                     verification_interval: 1, sleeper: Kernel.method(:sleep))
        administrator = Client.new(connection: administrator_connection)
        @snapshot = PlanSnapshot.new(administrator: administrator, audit_client: audit_client)
        @holder = Holder.new(administrator)
        @mutations = { 'add' => administrator_connection.method(:create_permission),
                       'delete' => administrator_connection.method(:delete_permission) }
        @readback = Readback.new(attempts: verification_attempts, interval: verification_interval, sleeper: sleeper)
        @results = {}
      end

      def inspect
        "#<#{self.class}>"
      end

      def execute(plan, apply: false, previous: nil)
        raise Error, 'Expected a reviewed permission plan' unless plan.is_a?(Plan)

        reviewed = Plan.load(plan.dump)
        digest = reviewed.to_h.fetch('digest')
        previous = @results[digest] if previous.nil?
        @results[digest] = ExecutionRun.new(plan: reviewed, snapshot: @snapshot, mutations: @mutations, holder: @holder,
                                            readback: @readback).execute(apply: apply, previous: previous)
      end
    end
  end
end
