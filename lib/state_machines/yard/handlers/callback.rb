# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Handles and processes the transition callbacks: before_transition,
      # after_transition, around_transition and after_failure. The
      # documented machine gets each callback with the methods it runs, the
      # transitions it runs on (from/to/on and their except_ forms, or
      # implicit from => to pairs) and its own conditions, read as the core
      # reads a transition's.
      class Callback < Base
        include Requirements

        # The DSL method of each callback kind
        KINDS = %i[before_transition after_transition around_transition after_failure].freeze
        # Options the core takes that change how a callback runs, not when
        BEHAVIOUR = %i[bind_to_object terminator].freeze

        KINDS.each { handles method_call(it) }

        # Store the handled method name for testing
        @handles_method = KINDS

        def process
          return unless owner.is_a?(StateMachines::Machine)

          owner.public_send(call_node.name, **callback_options)
        rescue Unreadable, ArgumentError => e
          # A callback that cannot be read, or that the core refuses, would be
          # documented as running on other transitions or methods than it does
          skip(call_node.name.to_s, e)
        end

        private

        def callback_options
          methods = positional_arguments.map { action(it) }
          options = option_pairs.each_with_object({}) do |(key, value), read|
            name = requirement(key)
            next if BEHAVIOUR.include?(name)

            if name == :do
              methods.concat(action_list(value))
            else
              read[name] = option_value(name, value)
            end
          end
          methods << block_action(call_node.block) if call_node.block
          options.merge(do: methods)
        end

        def action_list(node)
          node.is_a?(Prism::ArrayNode) ? node.elements.map { action(it) } : [action(node)]
        end

        # A method the callback runs, as the core reads it: a Symbol names a
        # method, a String is code. A lambda or proc is shown as diagrams show
        # a Proc, by where it is defined; any other code by its source.
        def action(node)
          case node
          when Prism::SymbolNode, Prism::StringNode then literal(node)
          else proc_literal?(node) ? lambda_label(node.location.start_line) : node.slice
          end
        end

        # ->, lambda {}, proc {} or Proc.new {}
        def proc_literal?(node)
          return true if node.is_a?(Prism::LambdaNode)
          return false unless node.is_a?(Prism::CallNode) && node.block

          node.receiver.nil? ? %i[lambda proc].include?(node.name) : proc_new?(node)
        end

        def proc_new?(node)
          node.name == :new && node.receiver.slice == 'Proc'
        end

        # The callback's own block, or a block argument: &:name as diagrams
        # show a Symbol's proc, anything else as an action
        def block_action(node)
          return lambda_label(node.location.start_line) if node.is_a?(Prism::BlockNode)

          expression = node.expression
          expression.is_a?(Prism::SymbolNode) ? "&#{expression.slice}" : action(expression)
        end

        # "lambda@file:line", the label diagrams give a Proc; +line+ counts
        # from the start of the statement
        def lambda_label(line)
          "lambda@#{File.basename(parser.file.to_s)}:#{statement.line + line - 1}"
        end
      end
    end
  end
end
