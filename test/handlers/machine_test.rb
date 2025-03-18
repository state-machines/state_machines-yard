require 'test_helper'

class MachineHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_machine_handler_registers_state_machine
    code = <<-RUBY
      class Vehicle
        # This is a state machine for vehicle status
        state_machine :status, initial: :parked do
          # States and events
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    assert has_attribute?(vehicle_class, 'state_machines'), "Vehicle class should have state_machines attribute"
    assert_equal 1, vehicle_class['state_machines'].size, "Vehicle should have one state machine"
    assert vehicle_class['state_machines'].key?(:status), "Vehicle should have a status state machine"
    
    machine = vehicle_class['state_machines'][:status]
    assert_equal :status, machine[:name], "Machine name should be :status"
    assert_equal "This is a state machine for vehicle status", machine[:description], "Machine description should match"
  end

  def test_machine_handler_with_default_name
    code = <<-RUBY
      class Vehicle
        # Default state machine
        state_machine do
          # States and events
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    assert vehicle_class['state_machines'].key?(:state), "Vehicle should have a default state machine"
  end

  def test_machine_handler_with_options
    code = <<-RUBY
      class Vehicle
        # State machine with options
        state_machine :status, initial: :parked, namespace: 'vehicle', attribute: :vehicle_status do
          # States and events
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    machine = vehicle_class['state_machines'][:status]
    refute_nil machine, "Status state machine should be registered"
  end
end