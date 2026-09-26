# frozen_string_literal: true

require_relative 'transition'

module JiraTk
  module Tickets
    # Status-only workflow operations through the client's existing transport.
    module Workflow
      def transitions(key)
        current = Transition.identity(get(key).fetch('fields')['status'])
        { 'key' => key, 'current' => current, 'transitions' => transition_options(key) }
      end

      def transition(key, to:, apply: false)
        validate_destination(to)
        before = get(key)
        current = Transition.identity(before.fetch('fields')['status'])
        return { 'key' => key, 'status' => 'unchanged', 'current' => current } if current['name'] == to

        selected = Transition.select(transition_options(key), to)
        result = { 'key' => key, 'status' => 'dry-run', 'from' => current, 'transition' => selected }
        return result unless apply == true

        recheck_transition(key, before, selected, to)
        apply_transition(key, selected)
        result.merge('status' => 'applied', 'current' => selected.fetch('to'))
      end

      private

      def validate_destination(target)
        return if target.is_a?(String) && !target.strip.empty?

        raise Error, 'Transition requires a nonempty destination status name'
      end

      def transition_options(key)
        response = request(:get, "#{issue_path(key)}/transitions", { expand: 'transitions.fields' })
        list = response_json(response, 200)['transitions']
        raise Error, 'Jira returned an invalid transition list' unless list.is_a?(Array)

        options = list.map { |item| Transition.new(item).to_h }
        ids = options.map { |item| item.fetch('id') }
        raise Error, 'Jira returned duplicate transition IDs' unless ids.uniq == ids

        options
      end

      def recheck_transition(key, before, selected, target)
        fresh = Transition.select(transition_options(key), target)
        return if fresh == selected && get(key) == before

        raise Error, 'Ticket or transition changed during preparation; read it again'
      end

      def apply_transition(key, selected)
        response = request(:post, "#{issue_path(key)}/transitions",
                           { transition: { id: selected.fetch('id') } }, debug: false)
        unless response.code == 204
          raise Error, "Ticket transition failed (HTTP #{response.code}); inspect before retrying"
        end

        verify_transition(key, selected.fetch('to'))
      end

      def verify_transition(key, destination)
        return if Transition.identity(get(key).fetch('fields')['status']) == destination

        raise Error, 'Status differs from the expected destination'
      rescue Error
        raise Error, 'Ticket transition could not be verified; inspect before retrying', cause: nil
      end
    end
  end
end
