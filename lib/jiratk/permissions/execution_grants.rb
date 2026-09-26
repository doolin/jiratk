# frozen_string_literal: true

require_relative 'plan'

module JiraTk
  module Permissions
    class ExecutionDrift < Error; end

    # Match complete grant sets to ordered prefixes and pin every observed ID.
    class ExecutionGrants
      attr_reader :operations

      def initialize(data)
        @data = data
        @bindings = {}
        @operations = data.fetch('steps').each_with_index.filter_map do |step, index|
          step.merge('step' => index + 1) if %w[add delete].include?(step['action'])
        end
        @stages = build_stages
      end

      def prefix(grants)
        index = @stages.index { |stage| matches?(stage, grants) }
        raise ExecutionDrift, 'Scheme grants differ from every reviewed prefix' unless index

        @stages[index].select { |grant| grant['id'].nil? }.each do |expected|
          actual = grants.find { |grant| grant.except('id') == expected.except('id') }
          bind(expected, actual['id'])
        end
        index
      end

      def acknowledge(step, grant)
        expected = addition(step)
        unless grant.except('id') == expected.except('id')
          raise Error, 'Created grant differs from the reviewed addition'
        end

        bind(expected, grant.fetch('id'))
      end

      def bindings
        @data.fetch('after_additions').filter_map do |grant|
          id = @bindings[identity(grant)]
          grant.merge('id' => id) if id
        end
      end

      def restore(grants)
        grants.each { |grant| bind(grant, grant.fetch('id')) }
      end

      private

      def addition(step)
        @data.fetch('after_additions').find do |grant|
          grant['id'].nil? && grant['holder'].slice('type', 'id') ==
            { 'type' => step['payload']['holder']['type'], 'id' => step['payload']['holder']['value'] }
        end
      end

      def build_stages
        stages = [@data.fetch('evidence').fetch('scheme').fetch('grants')]
        @operations.each do |step|
          current = stages.last
          stages << if step['action'] == 'add'
                      current + [addition(step)]
                    else
                      current.reject { |grant| grant['id'] == step['expected_grant']['id'] }
                    end
        end
        stages
      end

      def matches?(expected, actual)
        return false unless expected.length == actual.length

        expected.all? do |grant|
          id = grant['id'] || @bindings[identity(grant)]
          matches = actual.select { |item| item.except('id') == grant.except('id') }
          id ? matches.any? { |item| item['id'] == id } : matches.length == 1
        end
      end

      def identity(grant)
        PlanData.digest(grant.except('id'))
      end

      def bind(grant, id)
        id = Validation.id(id)
        key = identity(grant)
        original = @data.fetch('evidence').fetch('scheme').fetch('grants').map { |item| item['id'] }
        used = original + @bindings.except(key).values
        if used.include?(id) || (@bindings.key?(key) && @bindings[key] != id)
          raise ExecutionDrift, 'Added grant identity changed or reused an existing ID'
        end

        @bindings[key] = id
      end
    end
  end
end
