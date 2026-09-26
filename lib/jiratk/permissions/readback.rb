# frozen_string_literal: true

require_relative 'execution_grants'

module JiraTk
  module Permissions
    # Retries reads only. Drift stops immediately; uncertain writes are never replayed.
    class Readback
      def initialize(attempts: 3, interval: 1, sleeper: Kernel.method(:sleep))
        unless attempts.is_a?(Integer) && (1..5).cover?(attempts) &&
               valid_interval?(interval) && sleeper.respond_to?(:call)
          raise Error, 'Readback requires 1-5 attempts, a 0-5 second interval, and a callable sleeper'
        end

        @attempts = attempts
        @interval = interval
        @sleeper = sleeper
      end

      def inspect
        "#<#{self.class}>"
      end

      def verify(&)
        failure = nil
        @attempts.times do |index|
          @sleeper.call(@interval) if index.positive?
          failure = check(&)
          return failure if failure.nil? || failure['category'] == 'state_changed'
        end
        failure
      end

      private

      def valid_interval?(interval)
        interval.is_a?(Numeric) && interval.real? && interval.finite? && interval.between?(0, 5)
      end

      def check
        yield ? nil : { 'category' => 'verification_pending' }
      rescue ExecutionDrift
        { 'category' => 'state_changed' }
      rescue Error
        { 'category' => 'verification_read_failed' }
      end
    end
  end
end
