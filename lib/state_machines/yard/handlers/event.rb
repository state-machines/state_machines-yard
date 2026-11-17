# frozen_string_literal: true

module StateMachines
  module Yard
    module Handlers
      # Handles and processes #event
      class Event < Base
        handles method_call(:event)

        # Store the handled method name for testing
        @handles_method = :event

        def process
          return unless owner.is_a?(StateMachines::Machine)

          handler = self
          block = statement.block
          names = positional_arguments.flat_map { names_in(it) }
          options = literal_options(%i[human_name])

          names.each do |name|
            owner.event(name, **options) do
              handler.parse_block(block.last, owner: self) if block
            end
          end
        rescue Unreadable => e
          skip('event', e)
        end
      end
    end
  end
end
