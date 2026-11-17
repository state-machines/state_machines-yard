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
        # Literals whose value is never a method name (Symbol, String), Proc
        # or Method, which is all the core takes as a transition's callback
        NOT_METHODS = [
          *KEYWORDS.keys, *NUMBERS, Prism::RationalNode, Prism::ImaginaryNode, Prism::RegularExpressionNode,
          Prism::InterpolatedRegularExpressionNode, Prism::HashNode, Prism::RangeNode, Prism::SourceLineNode,
          Prism::SourceEncodingNode
        ].freeze

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

        # The methods of a before:/around:/after: option: one, or an Array of
        # them, each read through any parentheses around it. A literal that
        # is no method (nil, true, a number, a Regexp, a Hash, a Range, an
        # Array inside the list) is kept as code the core refuses, as it
        # refuses that literal when the class loads.
        def own_callbacks(node)
          node = unwrap(node)
          return node.elements.map { own_callback(it) } if node.is_a?(Prism::ArrayNode)

          own_callback(node)
        end

        def own_callback(node)
          node = unwrap(node)
          return Code.new(node.slice) if node.is_a?(Prism::ArrayNode) || nil_literal?(node) ||
                                         NOT_METHODS.any? { node.is_a?(it) }

          action(node)
        end
      end
    end
  end
end
