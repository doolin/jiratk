# frozen_string_literal: true

require_relative 'repair_membership'
require_relative 'repair_controls'
require_relative 'repair_grants'

module JiraTk
  module Permissions
    # Produces data-only steps; none can dispatch an HTTP mutation.
    class AssignRepair
      def initialize(request, evidence)
        @request = request
        @membership = RepairMembership.new(request, evidence)
        @controls = RepairControls.new(request, evidence)
        @grants = RepairGrants.new(request, evidence)
      end

      def build
        @controls.verify!
        @membership.verify!
        @grants.verify!
        if !@grants.target && @controls.before != @controls.after
          raise Error, 'Absent broad grant has unresolved negative controls'
        end

        { 'steps' => steps, 'after_additions' => @grants.after_additions, 'projected_grants' => @grants.projected,
          'protected_grants' => @grants.protected_grants,
          'controls' => { 'before_delete' => @controls.before, 'after_delete' => @controls.after } }
      end

      private

      def steps
        [{ 'action' => 'verify_preconditions', 'stage' => 'before_add' }] + @grants.replacements + [
          { 'action' => 'verify_replacements', 'scheme_id' => @request['scheme']['id'],
            'payloads' => @grants.replacements.map { |step| step['payload'] } },
          { 'action' => 'verify_controls', 'stage' => 'before_delete' },
          { 'action' => 'verify_preconditions', 'stage' => 'before_delete' },
          @grants.deletion,
          { 'action' => 'verify_projected_grants', 'scheme_id' => @request['scheme']['id'] },
          { 'action' => 'verify_controls', 'stage' => 'after_delete' }
        ]
      end
    end
  end
end
