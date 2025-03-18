require 'test_helper'
require 'nokogiri'

class TemplatesTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_html_template_rendering
    # Create a sample class with a state machine
    code = <<-RUBY
      # A vehicle class
      # @author Test Author
      class Vehicle
        # This is a state machine for vehicle status
        state_machine :status, initial: :parked do
          state :parked
          state :idling
          state :moving
          
          event :ignite do
            transition parked: :idling
          end
          
          event :drive do
            transition idling: :moving
          end
          
          event :park do
            transition moving: :parked
          end
        end
      end
    RUBY

    parse_code(code)
    
    # Generate documentation
    options = YARD::CLI::YardocOptions.new
    options.files = []
    options.output = @yard_dir
    
    YARD::CLI::Yardoc.run('--no-save', '--no-progress', '--quiet', '-o', @yard_dir)
    
    # Check if the HTML file was generated
    html_file = File.join(@yard_dir, 'Vehicle.html')
    assert File.exist?(html_file), "HTML file for Vehicle should exist"
    
    # Parse the HTML and check for state machine content
    html = File.read(html_file)
    doc = Nokogiri::HTML(html)
    
    # Check for state machine section
    state_machines_section = doc.at_css('h2:contains("State Machines")')
    refute_nil state_machines_section, "State Machines section should exist in the HTML"
    
    # Check for status machine
    status_machine = doc.at_css('h3:contains("status")')
    refute_nil status_machine, "Status machine heading should exist in the HTML"
    
    # Check for description
    description = status_machine.next_element
    refute_nil description, "Machine description should exist"
    assert_equal "This is a state machine for vehicle status", description.text.strip
  end
end