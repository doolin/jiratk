# frozen_string_literal: true

require_relative 'execution_state'
require_relative 'execution_result'
require_relative 'write_failure'

module JiraTk
  module Permissions
    # A new run owns its progress and evidence; no snapshots survive between runs.
    class ExecutionRun
      def initialize(plan:, snapshot:, mutations:, holder:, readback:)
        @state = ExecutionState.new(plan)
        @result = ExecutionResult.new(plan)
        @snapshot = snapshot
        @mutations = mutations
        @holder = holder
        @readback = readback
      end

      def inspect
        "#<#{self.class}>"
      end

      def execute(apply: false, previous: nil)
        restore(previous) unless previous.nil?
        observe
        return @result.fail('category' => 'unresolved_write') unless @result.resume_verified?(previous)
        return @result.finish('unchanged') if @state.complete?
        return @result.finish('dry-run') unless apply == true

        apply_remaining
      rescue ExecutionDrift
        @result.fail('category' => 'state_changed')
      rescue Error
        @result.fail('category' => 'precondition_failed')
      end

      private

      def restore(previous)
        @state.restore(@result.restore(previous))
      end

      def observe(maximum: @state.operations.length, pending: false)
        evidence = @snapshot.capture(@state.request)
        observation = @state.observe(evidence, maximum: maximum, pending: pending)
        @result.observe(@state, observation)
        observation
      end

      def apply_remaining
        @state.operations.each do |step|
          next if @result.completed?(step)

          observe(maximum: @state.prefix)
          failure = apply_step(step)
          return @result.fail(failure) if failure
        end
        @result.finish('applied')
      end

      def apply_step(step)
        target = @state.prefix + 1
        @result.attempt(step)
        failure = send_write(step)
        verification = @readback.verify do
          observation = observe(maximum: target, pending: true)
          @state.prefix == target && observation['controls_verified']
        end
        return verification unless failure

        @result.rejected(step) if failure.rejected?
        failure.details.merge('verification' => verification)
      end

      def send_write(step)
        response = @mutations.fetch(step['action']).call(step)
        @state.acknowledge(step, response, holder: @holder)
        @result.bind(@state)
        nil
      rescue WriteFailure => e
        e
      rescue Error
        WriteFailure.new('invalid_write_response')
      end
    end

    private_constant :ExecutionRun
  end
end
