# frozen_string_literal: true

require 'state_machines/diagram/introspection'

module StateMachines
  module Yard
    # A machine's events as text: the transitions each performs, as the core
    # resolves them (from one source the first matching branch), with their
    # guards and callbacks, labelled as the diagram renderers label them. The
    # documentation carries this whatever renderer draws, or none.
    module Description
      Introspection = StateMachines::Diagram::Introspection
      Labels = StateMachines::Diagram::Labels

      module_function

      # Each event as { name:, transitions: [line], failure: [callback] }, or
      # { name:, error: } when the core refuses one of its conditions (a
      # String it will not evaluate): it raises the same when it fires
      def events(machine)
        machine.events.map do |event|
          { name: event.name.to_s,
            transitions: Introspection.event_transitions(machine, event).map { transition(machine, event, *it) },
            failure: failure_callbacks(machine, event) }
        rescue SecurityError, ArgumentError => e
          { name: event.name.to_s, error: e.message, transitions: [], failure: [] }
        end
      end

      # "parked -> idling [if a && if_state gate=open] / before check, after log"
      def transition(machine, event, from, to, branch)
        guards = Labels.condition_phrases(Introspection.guard_conditions(branch))
        callbacks = Introspection.callback_labels(machine, from, to, event.name)
                                 .flat_map { |type, labels| labels.map { "#{type} #{it}" } }
        ["#{Labels.state_text(from)} -> #{Labels.state_text(to)}",
         ("[#{guards.join(' && ')}]" if guards.any?),
         ("/ #{callbacks.join(', ')}" if callbacks.any?)].compact.join(' ')
      end

      # The after_failure callbacks that run when the event fails
      def failure_callbacks(machine, event)
        machine.callbacks[:failure].select { it.branch.matches?(nil, on: event.name, guard: false) }
                                   .flat_map do |callback|
          conditions = Introspection.guard_conditions(callback.branch)
          callback.instance_variable_get(:@methods).map do |method|
            Labels.callback_text(label: Labels.action_label(method), conditions: conditions)
          end
        end
      end

      # The event's description lines for its methods' docstrings
      def docstring_lines(event)
        lines = if event[:error]
                  ['', "Its transitions cannot be described: #{event[:error]}"]
                elsif event[:transitions].empty?
                  ['', 'No transitions: it never fires.']
                else
                  ['', 'Transitions (from each state the first that matches is taken):', '',
                   *event[:transitions].map { "* #{it}" }]
                end
        lines += ['', "On failure: #{event[:failure].join(', ')}"] if event[:failure].any?
        lines + ['']
      end
    end
  end
end
