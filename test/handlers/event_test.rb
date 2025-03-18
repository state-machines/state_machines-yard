require 'test_helper'

class EventHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_event_handler_registers_events
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          # Ignition event
          event :ignite do
            transition parked: :idling
          end

          # Drive event
          event :drive do
            transition idling: :moving
          end
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check for methods that should be generated for events
    can_ignite_method = YARD::Registry.at('Vehicle#can_ignite?')
    refute_nil can_ignite_method, "can_ignite? method should be registered"
    assert_match(/Checks whether :ignite can be fired/, can_ignite_method.docstring.to_s)
    
    ignite_method = YARD::Registry.at('Vehicle#ignite')
    refute_nil ignite_method, "ignite method should be registered"
    assert_match(/Fires the :ignite event/, ignite_method.docstring.to_s)
    
    ignite_bang_method = YARD::Registry.at('Vehicle#ignite!')
    refute_nil ignite_bang_method, "ignite! method should be registered"
    assert_match(/Fires the :ignite event, raising an exception if it fails/, ignite_bang_method.docstring.to_s)
    
    ignite_transition_method = YARD::Registry.at('Vehicle#ignite_transition')
    refute_nil ignite_transition_method, "ignite_transition method should be registered"
    assert_match(/Gets the next transition that would be performed if :ignite were to be fired/, ignite_transition_method.docstring.to_s)
  end

  def test_event_handler_with_multiple_events
    code = <<-RUBY
      class Vehicle
        state_machine :status do
          # These are the possible events
          event :ignite, :drive, :park
        end
      end
    RUBY

    parse_code(code)
    
    vehicle_class = YARD::Registry.at('Vehicle')
    refute_nil vehicle_class, "Vehicle class should be registered"
    
    # Check for methods that should be generated for each event
    %w(ignite drive park).each do |event|
      can_method = YARD::Registry.at("Vehicle#can_#{event}?")
      refute_nil can_method, "can_#{event}? method should be registered"
      
      event_method = YARD::Registry.at("Vehicle##{event}")
      refute_nil event_method, "#{event} method should be registered"
      
      bang_method = YARD::Registry.at("Vehicle##{event}!")
      refute_nil bang_method, "#{event}! method should be registered"
      
      transition_method = YARD::Registry.at("Vehicle##{event}_transition")
      refute_nil transition_method, "#{event}_transition method should be registered"
    end
  end
end