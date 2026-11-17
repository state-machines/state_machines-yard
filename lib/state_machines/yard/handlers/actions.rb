# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Reads the methods a callback runs as the core reads them, for
      # handlers built on Base: a transition callback's (do:, positional, a
      # block) and a transition's own (before:, around:, after:)
      module Actions
        # Literals without to_proc: & raises TypeError on them, so the
        # declaration never runs. A Symbol and a Hash have one.
        NO_TO_PROC = [
          Prism::TrueNode, Prism::FalseNode, Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode,
          Prism::ImaginaryNode, Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode,
          Prism::InterpolatedXStringNode, Prism::SourceFileNode, Prism::SourceLineNode, Prism::SourceEncodingNode,
          Prism::ArrayNode, Prism::RangeNode, Prism::RegularExpressionNode, Prism::InterpolatedRegularExpressionNode
        ].freeze

        private

        # A do: option's methods: one, or an Array of them. The core reads
        # it with Array(), so nil (do: nil) is no method.
        def action_list(node)
          return [] if nil_literal?(node)

          node = unwrap(node)
          node.is_a?(Prism::ArrayNode) ? node.elements.map { action(it) } : [action(node)]
        end

        # A method the callback runs, as the core reads it: a Symbol names a
        # method, a String is code. A lambda or proc is shown as diagrams show
        # a Proc, by where it is defined; any other code by its source.
        def action(node)
          node = unwrap(node)
          case node
          when Prism::SymbolNode, Prism::StringNode then literal(node)
          else proc_literal?(node) ? lambda_label(node.location.start_line) : node.slice
          end
        end

        # The expression a group gives: (x), ((x)) and begin x end are x. An
        # empty group, or one of several expressions or with rescue / else /
        # ensure, stays itself (see #nil_literal?).
        def unwrap(node)
          single = single_statement(group_body(node)) if group?(node)
          single ? unwrap(single) : node
        end

        # nil, written as such or as an empty group: () or begin end
        def nil_literal?(node)
          node = unwrap(node)
          node.is_a?(Prism::NilNode) || (group?(node) && group_body(node).nil?)
        end

        def group?(node)
          node.is_a?(Prism::ParenthesesNode) ||
            (node.is_a?(Prism::BeginNode) && !node.rescue_clause && !node.else_clause && !node.ensure_clause)
        end

        def group_body(node) = node.is_a?(Prism::BeginNode) ? node.statements : node.body

        def single_statement(body)
          return body unless body.is_a?(Prism::StatementsNode)

          body.body.first if body.body.one?
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
        # show a Symbol's proc, a Hash's proc as diagrams show a Proc without
        # a source (lambda), anything else as an action. &nil passes no
        # block, so it is no method; a literal without to_proc raises
        # TypeError, so the declaration is refused as it never registers.
        def block_actions(node)
          return [lambda_label(node.location.start_line)] if node.is_a?(Prism::BlockNode)

          expression = unwrap(node.expression)
          return [] if nil_literal?(expression)
          if NO_TO_PROC.any? { expression.is_a?(it) }
            raise ArgumentError, "`#{node.slice}` is no block: Ruby raises TypeError, so the core never registers it"
          end

          [block_label(expression)]
        end

        def block_label(expression)
          case expression
          when Prism::SymbolNode then "&#{expression.slice}"
          when Prism::HashNode then 'lambda'
          else action(expression)
          end
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
