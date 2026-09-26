# frozen_string_literal: true

require_relative 'plan_data'

module JiraTk
  module Permissions
    # Mutation steps reference the original nine-step plan by one-based index.
    class ExecutionResult
      def initialize(plan)
        data = plan.to_h
        steps = data['steps'].each_with_index.filter_map do |step, index|
          next unless %w[add delete noop].include?(step['action'])

          { 'step' => index + 1, 'action' => step['action'], 'status' => 'pending' }
        end
        @data = { 'plan_digest' => data['digest'], 'status' => 'pending', 'exit_status' => nil,
                  'steps' => steps, 'write_attempts' => [], 'last_observation' => nil, 'failure' => nil,
                  'grant_bindings' => [], 'observed_prefix' => 0 }
      end

      def to_h
        PlanData.copy(@data)
      end

      def dump
        JSON.pretty_generate(to_h)
      end

      def observe(state, observation)
        completed = state.operations.take(state.prefix).map { |step| step['step'] }
        @data['steps'].each do |step|
          step['status'] = 'completed' if step['action'] == 'noop' || completed.include?(step['step'])
        end
        @data['last_observation'] = PlanData.copy(observation)
        bind(state)
      end

      def bind(state)
        @data['grant_bindings'] = PlanData.copy(state.bindings)
        @data['observed_prefix'] = state.prefix
      end

      def completed?(step)
        entry(step)['status'] == 'completed'
      end

      def attempt(step)
        @data['write_attempts'] << step['step']
        entry(step)['status'] = 'uncertain'
      end

      def rejected(step)
        entry(step)['status'] = 'failed' unless completed?(step)
      end

      def restore(previous)
        unless previous.is_a?(ExecutionResult) && previous.to_h['plan_digest'] == @data['plan_digest']
          raise Error, 'Previous execution must refer to the same reviewed plan'
        end

        data = previous.to_h
        @data.merge!(data.slice('steps', 'grant_bindings', 'observed_prefix', 'last_observation'))
        @data['steps'].each { |step| step['status'] = 'pending' if step['status'] == 'failed' }
        data
      end

      def resume_verified?(previous)
        return true if previous.nil?

        previous.to_h['steps'].none? { |step| step['status'] == 'uncertain' && !completed?(step) }
      end

      def finish(status)
        @data.merge!('status' => status, 'exit_status' => 0)
        self
      end

      def fail(details)
        @data.merge!('status' => 'failed', 'exit_status' => @data['write_attempts'].empty? ? 2 : 3,
                     'failure' => PlanData.copy(details))
        self
      end

      private

      def entry(step)
        @data['steps'].find { |item| item['step'] == step['step'] }
      end
    end
  end
end
