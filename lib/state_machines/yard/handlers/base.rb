# frozen_string_literal: true

require 'prism'

module StateMachines
  module Yard
    module Handlers
      # Handles and processes nodes. A handler reads its call's arguments
      # from the source with Prism and takes only what is written as a
      # literal: nothing in the documented code is run.
      class Base < YARD::Handlers::Ruby::Base
        # An argument that is not a literal, so its value is only known when
        # the code runs
        class Unreadable < StandardError; end

        # Code the documented source holds where the core takes a value (a
        # state's value: or human_name:), shown as it is written
        Code = Data.define(:source) do
          def to_s = source
          def inspect = source
        end

        # The literals Ruby spells as keywords
        KEYWORDS = { Prism::NilNode => nil, Prism::TrueNode => true, Prism::FalseNode => false }.freeze
        NUMBERS = [Prism::IntegerNode, Prism::FloatNode].freeze
        # The literals a name can be
        NAMES = [Symbol, String, Integer, Float, TrueClass, FalseClass].freeze
        # Text literals, and how each turns its text into its value
        TEXTS = { Prism::SymbolNode => :to_sym, Prism::StringNode => :itself }.freeze

        private

        # The handled call as Prism reads it
        def call_node
          @call_node ||= begin
            source = call_source
            node = Prism.parse(source).value.statements.body.first
            raise Unreadable, "`#{source}` is not a plain call" unless node.is_a?(Prism::CallNode)

            node
          end
        end

        # The handled call's source, as Prism reads it in the file. YARD's
        # parser ends a statement before a trailing rational or imaginary
        # literal (`after: 1r` reads `after:`, which Prism reads as a call to
        # `after`) and past a trailing negative number (`-1 }`), so the call is
        # the one Prism finds where the statement starts.
        def call_source
          FileSource.call_at(statement.full_source, statement.source_range.begin)&.slice || statement.source
        end

        # The calls of the file being documented, read once per file
        module FileSource
          @calls = nil

          # The innermost call starting at character +offset+ of +source+
          def self.call_at(source, offset)
            @calls = [source, calls_by_offset(source)] unless @calls&.first.equal?(source)
            @calls.last[offset]
          end

          def self.calls_by_offset(source)
            calls = Prism.parse(source).value.breadth_first_search_all { it.is_a?(Prism::CallNode) }
            calls.group_by { it.location.start_character_offset }.transform_values { it.min_by { it.location.length } }
          end
        end

        # The call's positional arguments, as nodes
        def positional_arguments
          arguments = call_node.arguments&.arguments || []
          options_node?(arguments.last) ? arguments[0...-1] : arguments
        end

        # The call's trailing options Hash, as [key node, value node] pairs
        def option_pairs
          last = call_node.arguments&.arguments&.last
          options_node?(last) ? pairs(last) : []
        end

        def options_node?(node)
          node.is_a?(Prism::KeywordHashNode) || node.is_a?(Prism::HashNode)
        end

        def pairs(node)
          node.elements.map do |element|
            unreadable(element) unless element.is_a?(Prism::AssocNode)

            [element.key, element.value]
          end
        end

        # The value of a literal: a Symbol, String, nil, true, false, number,
        # or an Array or Hash of those
        def literal(node)
          case node
          when *TEXTS.keys then node.unescaped.public_send(TEXTS.fetch(node.class))
          when *KEYWORDS.keys then KEYWORDS.fetch(node.class)
          when *NUMBERS then node.value
          when Prism::ArrayNode then node.elements.map { literal(it) }
          when Prism::HashNode then pairs(node).to_h { |key, value| [literal(key), literal(value)] }
          else unreadable(node)
          end
        end

        # A state, event or machine name: any literal the core takes as one,
        # a Symbol, String, number, true or false (or nil, the nil state,
        # when +nil_allowed+)
        def name_literal(node, nil_allowed: false)
          value = literal(node)
          return value if NAMES.any? { value.is_a?(it) } || (nil_allowed && value.nil?)

          unreadable(node)
        end

        # The names one argument gives: a name, or an Array of them
        def names_in(node, nil_allowed: false)
          return [name_literal(node, nil_allowed: nil_allowed)] unless node.is_a?(Prism::ArrayNode)

          node.elements.map { name_literal(it, nil_allowed: nil_allowed) }
        end

        # The literal options among +keys+; any other option is left out. An
        # option written as code is a Code of its source when it is one of
        # +code+, and otherwise left out; either way with a warning, since
        # the documentation cannot show its value.
        def literal_options(keys, code: [])
          option_pairs.each_with_object({}) do |(key, value), options|
            name = literal(key)
            next unless keys.include?(name)

            options[name] = option_literal(name, value, code)
          rescue Unreadable
            next
          end
        end

        def option_literal(name, node, code)
          literal(node)
        rescue Unreadable
          documented = code.include?(name) ? 'documented as its source' : 'left out'
          log.warn "state_machines-yard: #{name}: is code (`#{node.slice}`), #{documented} " \
                   "(#{parser.file}:#{statement.line})"
          raise unless code.include?(name)

          Code.new(node.slice)
        end

        def unreadable(node)
          raise Unreadable, "`#{node.slice}` is code, not a literal"
        end

        # Logs that +what+ is left out of the documentation, and why
        def skip(what, error)
          log.warn "state_machines-yard: #{what} is not documented: #{error.message} " \
                   "(#{parser.file}:#{statement.line})"
        end
      end
    end
  end
end
