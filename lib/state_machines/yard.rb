# frozen_string_literal: true

require 'yard'
require 'state_machines'
require_relative 'yard/version'
module StateMachines
  # YARD plugin for automated documentation
  module Yard
  end
end

require_relative 'yard/description'
require_relative 'yard/handlers'
require_relative 'yard/handlers/base'
require_relative 'yard/handlers/requirements'
require_relative 'yard/handlers/actions'
require_relative 'yard/handlers/callback'
require_relative 'yard/handlers/event'
require_relative 'yard/handlers/machine'
require_relative 'yard/handlers/state'
require_relative 'yard/handlers/transition'
require_relative 'yard/templates'
