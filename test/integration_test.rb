require 'test_helper'

class IntegrationTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_full_documentation_integration
    # Create a more complex class with state machine
    code = <<-RUBY
      # A vehicle class representing automobiles
      # @author Test Author
      class Vehicle
        # The vehicle's engine state
        # @return [Boolean] true if the engine is on, false otherwise
        attr_accessor :engine_on
        # Status state machine tracks the operational status of the vehicle
        state_machine :status, initial: :parked do
          description "Controls the vehicle's operational status"
          
          # Parked state - vehicle is not moving and can be started
          state :parked do
            description "Vehicle is stopped and secured"
          end
          
          # Idling state - engine is running but vehicle is not moving
          state :idling do
            description "Engine is running but vehicle is stationary"
          end
          
          # Moving state - vehicle is in motion
          state :moving do
            description "Vehicle is in motion"
          end
          
          # Stalled state - vehicle has encountered a problem
          state :stalled do
            description "Vehicle has encountered a problem"
          end
          
          # Ignition event - turns on the engine
          event :ignite do
            description "Starts the vehicle's engine"
            transition parked: :idling
          end
          
          # Drive event - puts vehicle in motion
          event :drive do
            description "Puts the vehicle in motion"
            transition idling: :moving
          end
          
          # Stop event - brings vehicle to a stop
          event :stop do
            description "Stops the vehicle"
            transition moving: :idling
          end
          
          # Park event - secure the vehicle
          event :park do
            description "Secures the vehicle"
            transition idling: :parked
          end
          
          # Stall event - unexpected problem
          event :stall do
            description "Vehicle encountered a problem"
            transition [:idling, :moving] => :stalled
          end
          
          # Repair event - fix the stalled vehicle
          event :repair do
            description "Fix vehicle issues"
            transition stalled: :parked
          end
        end
        
        # Second state machine for the gear position
        state_machine :gear, initial: :neutral do
          state :neutral
          state :first
          state :second
          state :third
          
          event :shift_up do
            transition neutral: :first, first: :second, second: :third
          end
          
          event :shift_down do
            transition third: :second, second: :first, first: :neutral
          end
        end
      end
    RUBY

    parse_code(code)
    
    # Verify YARD Registry
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check state machines attribute exists
    assert has_attribute?(vehicle_class, 'state_machines'), "Vehicle class should have state_machines attribute"
    assert_equal 2, vehicle_class['state_machines'].size, "Vehicle should have two state machines"
    
    # Check both state machines exist
    assert vehicle_class['state_machines'].key?(:status), "Vehicle should have a status state machine"
    assert vehicle_class['state_machines'].key?(:gear), "Vehicle should have a gear state machine"
    
    # Check state methods
    %w(parked? idling? moving? stalled? neutral? first? second? third?).each do |method_name|
      method = YARD::Registry.at("Vehicle##{method_name}")
      refute_nil method, "#{method_name} method should be registered"
    end
    
    # Check event methods for status machine
    %w(ignite drive stop park stall repair).each do |event|
      method = YARD::Registry.at("Vehicle##{event}")
      refute_nil method, "#{event} method should be registered"
      bang_method = YARD::Registry.at("Vehicle##{event}!")
      refute_nil bang_method, "#{event}! method should be registered"
    end
    
    # Check event methods for gear machine
    %w(shift_up shift_down).each do |event|
      method = YARD::Registry.at("Vehicle##{event}")
      refute_nil method, "#{event} method should be registered"
      bang_method = YARD::Registry.at("Vehicle##{event}!")
      refute_nil bang_method, "#{event}! method should be registered"
    end
    
    # Check attribute-related methods
    status_method = YARD::Registry.at("Vehicle#status")
    refute_nil status_method, "status method should be registered"

    status_events_method = YARD::Registry.at("Vehicle#status_events")
    refute_nil status_events_method, "status_events method should be registered"
    
    # Generate documentation
    YARD::CLI::Yardoc.run('--no-save', '--no-progress', '--quiet', '-o', @yard_dir)
    
    # Check if the HTML file was generated
    html_file = File.join(@yard_dir, 'Vehicle.html')
    assert File.exist?(html_file), "HTML file for Vehicle should exist"
  end
end