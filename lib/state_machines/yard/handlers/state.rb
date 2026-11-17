# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Handles and processes #state
      class State < Base
        handles method_call(:state)

        # Store the handled method name for testing
        @handles_method = :state

        def process
          return unless owner.is_a?(StateMachines::Machine)

          handler = self
          block = statement.block
          names = positional_arguments.flat_map { names_in(it, nil_allowed: true) }
          options = literal_options(%i[value human_name])

          names.each do |name|
            owner.state(name, **options) do
              handler.parse_block(block.last, owner: self) if block
            end
          end
        rescue Unreadable => e
          skip('state', e)
        end
      end
    end
  end
end
