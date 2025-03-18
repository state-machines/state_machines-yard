require 'minitest/autorun'
require 'yard'
require 'state_machines'
require 'state_machines/yard'
require 'state_machines/graphviz'
require 'nokogiri'
require 'fileutils'

# Helper module for tests
module TestHelpers
  # Create a temporary directory for YARD outputs
  def setup_yard
    @yard_dir = File.expand_path('../tmp/yard', __dir__)
    FileUtils.rm_rf(@yard_dir) if Dir.exist?(@yard_dir)
    FileUtils.mkdir_p(@yard_dir)
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