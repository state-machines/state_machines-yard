# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Reads the requirements and guards a transition or callback declares,
      # as the core reads them, for handlers built on Base
      module Requirements
        # Conditions on the object
        CONDITIONS = %i[if unless].freeze
        # Conditions on the states of other machines, each a group of
        # machine => state requirements
        STATE_GUARDS = %i[if_state unless_state if_all_states unless_all_states if_any_state
                          unless_any_state].freeze
        # The matchers the DSL names
        MATCHERS = { all: AllMatcher, any: AllMatcher, same: LoopbackMatcher }.freeze

        private

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
        # when it runs, so its source is documented as the condition
        # (#condition_term).
        def condition(node)
          case node
          when Prism::NilNode then nil
          when Prism::FalseNode then false
          when Prism::ArrayNode then node.elements.map { condition_term(it) }
          else condition_term(node)
          end
        end

        # A Symbol or String condition as written. Code (a lambda, a method
        # call) is kept as a Symbol of its source: diagrams show it as
        # written, and it is never taken for a String condition, which the
        # core (and diagram introspection) validates and evaluates as code.
        def condition_term(node)
          case node
          when Prism::SymbolNode, Prism::StringNode then literal(node)
          else node.slice.to_sym
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
