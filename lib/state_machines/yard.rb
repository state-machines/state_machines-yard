require 'yard'
require_relative 'yard/version'
module StateMachines
  # YARD plugin for automated documentation
  module Yard
  end
end

require_relative 'yard/handlers'
require_relative 'yard/handlers/base'
require_relative 'yard/handlers/event'
require_relative 'yard/handlers/machine'
require_relative 'yard/handlers/state'
require_relative 'yard/handlers/transition'
require_relative 'yard/templates'
