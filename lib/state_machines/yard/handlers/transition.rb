# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Handles and processes #transition. The documented machine gets the
      # transition with the guards the core runs: if:/unless: conditions
      # (each one of an Array, a String as the code it is, any other code
      # by its source) and state guards with the requirements of each group,
      # and its own before:/around:/after: callbacks, each method read as a
      # transition callback's (Actions): a lambda or other code is a method
      # the transition runs, not a state.
      class Transition < Base
        handles method_call(:transition)

        # Store the handled method name for testing
        @handles_method = :transition

        include Requirements
        include Actions

        # What a transition is declared on: a machine, an event, or a state's
        # block (state :parked do ... end), whose owner is its StateContext
        OWNERS = [StateMachines::Machine, StateMachines::Event, StateMachines::StateContext].freeze
        # The options that hold the transition's own callbacks
        CALLBACKS = %i[before around after].freeze
        # Literals the core never takes as a method
        NOT_METHODS = [*KEYWORDS.keys, *NUMBERS, Prism::HashNode].freeze

        def process
          return unless OWNERS.include?(owner.class)

          owner.transition(requirements)
        rescue Unreadable, ArgumentError => e
          # A transition that cannot be read, or that the core refuses, would
          # be documented with other requirements or guards than it has
          skip('transition', e)
        end

        private

        def requirements
          pairs = option_pairs
          unreadable(call_node) if pairs.empty?

          pairs.to_h do |key, value|
            name = requirement(key)
            [name, CALLBACKS.include?(name) ? own_callbacks(value) : option_value(name, value)]
          end
        end

        # The methods of a before:/around:/after: option. A literal that is
        # no method (nil, true, a number, a Hash) stays itself, so the core
        # refuses it as it would when the class loads.
        def own_callbacks(node)
          return literal(node) if NOT_METHODS.any? { node.is_a?(it) }

          node.is_a?(Prism::ArrayNode) ? node.elements.map { own_callbacks(it) } : action(node)
        end
      end
    end
  end
end
