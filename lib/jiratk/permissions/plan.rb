# frozen_string_literal: true

require_relative 'repair_request'
require_relative 'plan_evidence'
require_relative 'assign_repair'

module JiraTk
  module Permissions
    # A digest detects edits; it is neither authorization nor a signature.
    class Plan
      VERSION = 1

      def initialize(request:, evidence:, created_at: Time.now.utc.iso8601)
        request = RepairRequest.from_h(request).to_h
        evidence = PlanEvidence.new(evidence).to_h
        @data = PlanData.canonical(
          { 'version' => VERSION, 'created_at' => PlanData.timestamp(created_at),
            'request' => request, 'evidence' => evidence }.merge(AssignRepair.new(request, evidence).build)
        )
      rescue KeyError, TypeError
        raise Error, 'Plan data is incomplete or invalid', cause: nil
      end

      def self.load(json)
        data = Validation.object(JSON.parse(Validation.text(json), allow_duplicate_key: false))
        raise Error, 'Unsupported permission plan version' unless data['version'] == VERSION

        plan = new(request: data.fetch('request'), evidence: data.fetch('evidence'),
                   created_at: data.fetch('created_at'))
        raise Error, 'Permission plan content or digest differs' unless plan.to_h == data

        plan
      rescue JSON::ParserError, KeyError, TypeError
        raise Error, 'Saved permission plan is invalid', cause: nil
      end

      def inspect
        "#<#{self.class} digest=#{PlanData.digest(@data)}>"
      end

      def to_h
        PlanData.copy(@data).merge('digest' => PlanData.digest(@data))
      end

      def dump
        JSON.pretty_generate(to_h)
      end

      def request
        PlanData.copy(@data['request'])
      end

      def preconditions
        data = PlanData.copy(@data['evidence'])
        data['audit'].delete('timestamp')
        data
      end
    end
  end
end
