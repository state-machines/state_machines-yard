# frozen_string_literal: true

module StateMachines
  module Yard
    # YARD custom handlers for integrating the state_machine DSL with the
    # YARD documentation system
    module Handlers
      require_relative 'handlers/base'
      require_relative 'handlers/event'
      require_relative 'handlers/machine'
      require_relative 'handlers/state'
      require_relative 'handlers/transition'
    end
  end
end
