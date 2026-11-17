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
        include Actions

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
      end
    end
  end
end
