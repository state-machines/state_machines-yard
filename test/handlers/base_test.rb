require 'test_helper'

class BaseHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_extract_node_name_with_symbol
    code = <<-RUBY
      class TestClass
        state_machine :status do
          # Test using a symbol
          state :parked
        end
      end
    RUBY

    parse_code(code)
    
    # We can't directly test the extract_node_name method since it's private
    # But we can test that symbol nodes were correctly processed
    test_class = YARD::Registry.at('TestClass')
    refute_nil test_class, "TestClass should be registered"
    
    parked_method = YARD::Registry.at('TestClass#parked?')
    refute_nil parked_method, "parked? method should be registered"
  end

  def test_extract_node_name_with_string
    code = <<-RUBY
      class TestClass
        state_machine :status do
          # Test using a string
          state "moving"
        end
      end
    RUBY

    parse_code(code)
    
    # Test that string nodes were correctly processed
    test_class = YARD::Registry.at('TestClass')
    refute_nil test_class, "TestClass should be registered"
    
    moving_method = YARD::Registry.at('TestClass#moving?')
    refute_nil moving_method, "moving? method should be registered"
  end

  def test_extract_node_names_with_array
    code = <<-RUBY
      class TestClass
        state_machine :status do
          # Test using an array
          state :parked, :idling, :moving
        end
      end
    RUBY

    parse_code(code)
    
    # Test that array nodes were correctly processed
    test_class = YARD::Registry.at('TestClass')
    refute_nil test_class, "TestClass should be registered"
    
    %w(parked idling moving).each do |state|
      method = YARD::Registry.at("TestClass##{state}?")
      refute_nil method, "#{state}? method should be registered"
    end
  end
end