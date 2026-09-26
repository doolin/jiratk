# frozen_string_literal: true

require_relative 'execution_grants'

module JiraTk
  module Permissions
    # Only reviewed grants and the planned final control changes may vary.
    class ExecutionState
      attr_reader :prefix, :request, :operations

      def initialize(plan)
        @data = plan.to_h
        @request = RepairRequest.from_h(plan.request)
        @grants = ExecutionGrants.new(@data)
        @operations = @grants.operations
        @prefix = 0
      end

      def observe(raw, maximum: @operations.length, pending: false)
        evidence = PlanEvidence.new(raw).to_h
        unless fixed(evidence) == fixed(@data.fetch('evidence'))
          raise ExecutionDrift, 'Identity, inventory, scheme or membership evidence changed'
        end

        prefix = @grants.prefix(evidence.fetch('scheme').fetch('grants'))
        raise ExecutionDrift, 'Execution progress changed unexpectedly' unless (@prefix..maximum).cover?(prefix)

        ready = controls(evidence, prefix, pending)
        @prefix = prefix
        { 'prefix' => prefix, 'controls_verified' => ready, 'evidence' => evidence }
      end

      def acknowledge(step, response, holder:)
        return if step['action'] == 'delete'

        data = Validation.object(response)
        grant = { 'id' => Validation.id(data['id']), 'permission' => Validation.text(data['permission']),
                  'holder' => holder.normalize(data['holder']) }
        @grants.acknowledge(step, grant)
      end

      def complete?
        @prefix == @operations.length
      end

      def bindings
        @grants.bindings
      end

      def restore(previous)
        @grants.restore(previous.fetch('grant_bindings'))
        @prefix = previous.fetch('observed_prefix')
      end

      private

      def fixed(evidence)
        data = PlanData.copy(evidence)
        data['scheme'].delete('grants')
        data['audit'].delete('timestamp')
        data['audit']['projects'].each { |project| project.delete('permissions') }
        data
      end

      def controls(evidence, prefix, pending)
        actual = evidence['audit']['projects'].to_h { |project| [project['key'], project['permissions']] }
        final = prefix == @operations.length
        expected = @data['controls'].fetch(final ? 'after_delete' : 'before_delete')
        return true if actual == expected
        return false if final && pending && propagating?(actual)

        raise ExecutionDrift, 'Permission controls changed unexpectedly'
      end

      def propagating?(actual)
        actual.all? do |project, permissions|
          permissions.all? do |key, value|
            [@data['controls']['before_delete'][project][key],
             @data['controls']['after_delete'][project][key]].include?(value)
          end
        end
      end
    end
  end
end
