module StateMachines
  module Yard
    module Handlers
      # Handles and processes #event
      class Event < Base
        handles method_call(:event)
        
        # Store the handled method name for testing
        @handles_method = :event

        def process
          if owner.is_a?(StateMachines::Machine)
            handler = self
            statement = self.statement
            names = extract_node_names(statement.parameters(false))

            names.each do |name|
              owner.event(name) do
                # Parse the block only if it exists
                if statement.block
                  handler.parse_block(statement.block.last, owner: self)
                end
              end
            end
          end
        end
      end
    end
  end
end
