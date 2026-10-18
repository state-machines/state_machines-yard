require 'minitest/autorun'
require 'yard'
require 'state_machines'
require 'state_machines/yard'
case ENV['STATE_MACHINES_RENDERER']
when 'graphviz'
  require 'state_machines/graphviz'
when 'mermaid'
  require 'state_machines-mermaid'
end
require 'nokogiri'
require 'fileutils'
require 'tmpdir'

# Helper module for tests
module TestHelpers
  # Create a temporary directory for YARD outputs
  def setup_yard
    @yard_dir = Dir.mktmpdir('state_machines-yard')
    YARD::Registry.clear
    # Register our handlers
    YARD::Tags::Library.define_tag("State Machines", :state_machines)
  end

  # Parse the given code with YARD
  def parse_code(code)
    YARD.parse_string(code)
    YARD::Registry.load
  end

  # Clean up after test
  def cleanup_yard
    FileUtils.rm_rf(@yard_dir) if Dir.exist?(@yard_dir)
    YARD::Registry.clear
  end
  
  # Helper method to check if registry object has attribute
  def has_attribute?(obj, name)
    obj.respond_to?(:[]) && obj[name] != nil
  end
end
