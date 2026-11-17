# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Handles and processes #transition. The documented machine gets the
      # transition with the guards the core runs: if:/unless: conditions
      # (each one of an Array, a String as the code it is, any other code
      # by its source) and state guards with the requirements of each group.
      class Transition < Base
        handles method_call(:transition)

        # Store the handled method name for testing
        @handles_method = :transition

        include Requirements

        # What a transition is declared on: a machine, an event, or a state's
        # block (state :parked do ... end), whose owner is its StateContext
        OWNERS = [StateMachines::Machine, StateMachines::Event, StateMachines::StateContext].freeze

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
            [name, option_value(name, value)]
          end
        end
      end
    end
  end
end
