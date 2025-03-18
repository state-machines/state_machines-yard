require 'test_helper'

class TransitionHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_transition_handler_in_event_context
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          event :ignite do
            # Transition from parked to idling
            transition parked: :idling
          end
        end
      end
    RUBY

    parse_code(code)
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check for transitions documentation through the event methods
    ignite_method = YARD::Registry.at('Vehicle#ignite')
    refute_nil ignite_method, "ignite method should be registered"
  end

  def test_transition_handler_with_multiple_states
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          event :drive do
            # Transition from multiple states
            transition [:idling, :parked] => :moving
          end
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # The drive method should be registered
    drive_method = YARD::Registry.at('Vehicle#drive')
    refute_nil drive_method, "drive method should be registered"
  end

  def test_transition_handler_with_conditional
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          event :drive do
            # Transition with a conditional
            transition parked: :moving, if: :engine_started?
          end
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # The drive method should be registered despite the conditional
    drive_method = YARD::Registry.at('Vehicle#drive')
    refute_nil drive_method, "drive method should be registered"
  end

  def test_transition_handler_with_special_matchers
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          event :repair do
            # Use 'all' matcher
            transition any => :parked
          end
          
          event :maintain do
            # Use 'same' matcher
            transition all => same
          end
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Both methods should be registered
    repair_method = YARD::Registry.at('Vehicle#repair')
    refute_nil repair_method, "repair method should be registered"
    
    maintain_method = YARD::Registry.at('Vehicle#maintain')
    refute_nil maintain_method, "maintain method should be registered"
  end
end