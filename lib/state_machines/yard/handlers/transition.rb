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

        # Conditions on the object
        CONDITIONS = %i[if unless].freeze
        # Conditions on the states of other machines, each a group of
        # machine => state requirements
        STATE_GUARDS = %i[if_state unless_state if_all_states unless_all_states if_any_state
                          unless_any_state].freeze
        # The matchers the DSL names
        MATCHERS = { all: AllMatcher, any: AllMatcher, same: LoopbackMatcher }.freeze

        def process
          return unless [StateMachines::Machine, StateMachines::Event, StateMachines::State].include?(owner.class)

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

        def option_value(name, node)
          if CONDITIONS.include?(name) then condition(node)
          elsif STATE_GUARDS.include?(name) then state_guard(node)
          else requirement(node)
          end
        end

        # A state or event requirement: a name, an Array of names, or a
        # matcher (all, any, same, all - names)
        def requirement(node)
          case node
          when Prism::CallNode then matcher(node)
          when Prism::ArrayNode then node.elements.map { name_literal(it, nil_allowed: true) }
          else name_literal(node, nil_allowed: true)
          end
        end

        def matcher(node)
          return MATCHERS.fetch(node.name).instance if bare_call?(node) && MATCHERS.key?(node.name)
          return AllMatcher.instance - names_in(node.arguments.arguments.first, nil_allowed: true) if exclusion?(node)

          unreadable(node)
        end

        # all - names, any - names
        def exclusion?(node)
          node.name == :- && all_matcher?(node.receiver) && node.arguments&.arguments&.one?
        end

        def all_matcher?(node)
          node.is_a?(Prism::CallNode) && bare_call?(node) && MATCHERS[node.name] == AllMatcher
        end

        def bare_call?(node)
          node.receiver.nil? && node.arguments.nil? && node.block.nil?
        end

        # An if:/unless: condition as the core reads it: nil and false are no
        # condition, an Array is several, a Symbol names a method, a String is
        # code. Anything else is code (a lambda, a method call) only known
        # when it runs, so its source is documented as the condition.
        def condition(node)
          case node
          when Prism::NilNode then nil
          when Prism::FalseNode then false
          when Prism::ArrayNode then node.elements.map { condition_term(it) }
          else condition_term(node)
          end
        end

        def condition_term(node)
          case node
          when Prism::SymbolNode, Prism::StringNode then literal(node)
          else node.slice
          end
        end

        # A state guard: a Hash of machine => state, kept as one group
        def state_guard(node)
          guard = literal(node)
          unreadable(node) unless guard.is_a?(Hash)

          guard
        end
      end
    end
  end
end
