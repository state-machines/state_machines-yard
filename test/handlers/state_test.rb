require 'test_helper'

class StateHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_state_handler_registers_states
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          # Parked state
          state :parked do
            # State behavior
          end

          # Moving state
          state :moving
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check for methods that should be generated for states
    parked_method = YARD::Registry.at('Vehicle#parked?')
    refute_nil parked_method, "parked? method should be registered"
    assert_equal "Checks whether :parked is the current state.", parked_method.docstring.to_s
    
    moving_method = YARD::Registry.at('Vehicle#moving?')
    refute_nil moving_method, "moving? method should be registered"
    assert_equal "Checks whether :moving is the current state.", moving_method.docstring.to_s
  end

  def test_state_handler_with_multiple_states
    code = <<-RUBY
      class Vehicle
        state_machine :status do
          # These are the possible states
          state :parked, :idling, :moving
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check for methods that should be generated for each state
    %w(parked idling moving).each do |state|
      method = YARD::Registry.at("Vehicle##{state}?")
      refute_nil method, "#{state}? method should be registered"
      assert_equal "Checks whether :#{state} is the current state.", method.docstring.to_s
    end
  end
end