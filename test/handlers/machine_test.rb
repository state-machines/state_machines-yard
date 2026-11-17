# frozen_string_literal: true

require 'test_helper'

class MachineHandlerTest < Minitest::Test
  include TestHelpers

  RENDERER_VARIABLE = 'STATE_MACHINES_RENDERER'
  DIAGRAM_RENDERER = 'mermaid'
  NIL_STATE_ID = 'nil_state'

  NAMESPACED_MACHINES = <<~RUBY
    module Air
      class Craft
        state_machine initial: :grounded do
          event :launch do
            transition grounded: :airborne
          end
        end
      end
    end

    module Sea
      class Craft
        state_machine initial: :docked do
          event :launch do
            transition docked: :sailing
          end
        end
      end
    end

    module Air
      class Glider < Craft
        state_machine do
          state :towed
        end
      end
    end
  RUBY

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_classes_sharing_a_short_name_do_not_share_an_inherited_machine
    previous_renderer = ENV.fetch(RENDERER_VARIABLE, nil)
    ENV[RENDERER_VARIABLE] = DIAGRAM_RENDERER
    begin
      parse_code(NAMESPACED_MACHINES)
    ensure
      ENV[RENDERER_VARIABLE] = previous_renderer
    end

    diagram = YARD::Registry.at('Air::Glider')['state_machines'][:state][DIAGRAM_RENDERER.to_sym]
    documented_states = (diagram.scan(/^\s+(\S+) : /).flatten - [NIL_STATE_ID]).sort

    eval(NAMESPACED_MACHINES, TOPLEVEL_BINDING) # rubocop:disable Security/Eval -- the fixture, run to compare
    actual_states = Air::Glider.state_machines[:state].states.filter_map(&:name).map(&:to_s).sort

    assert_equal actual_states, documented_states
  end

  def test_a_subclass_machine_documents_the_methods_that_read_its_state
    parse_code(<<~RUBY)
      class Vehicle
        state_machine :status, initial: :parked do
          event(:ignite) { transition parked: :idling }
        end
      end

      class Car < Vehicle
        state_machine :status do
          state :towed
        end
      end
    RUBY

    %w[Car#status? Car#status_name Car#human_status_name Car#towed?].each do |path|
      refute_nil YARD::Registry.at(path), "#{path} should be documented"
    end
    # Listed and fired through the superclass's machine
    assert_nil YARD::Registry.at('Car#status_events')
    assert_nil YARD::Registry.at('Car#ignite')
    # The subclass's states stay its own
    assert_nil YARD::Registry.at('Vehicle#towed?')
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

    refute_nil vehicle_class, 'Vehicle class should be registered'
    assert attribute?(vehicle_class, 'state_machines'), 'Vehicle class should have state_machines attribute'
    assert_equal 1, vehicle_class['state_machines'].size, 'Vehicle should have one state machine'
    assert vehicle_class['state_machines'].key?(:status), 'Vehicle should have a status state machine'

    machine = vehicle_class['state_machines'][:status]

    assert_equal :status, machine[:name], 'Machine name should be :status'
    assert_equal 'This is a state machine for vehicle status', machine[:description], 'Machine description should match'
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

    refute_nil vehicle_class, 'Vehicle class should be registered'
    assert vehicle_class['state_machines'].key?(:state), 'Vehicle should have a default state machine'
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

    refute_nil vehicle_class, 'Vehicle class should be registered'

    machine = vehicle_class['state_machines'][:status]

    refute_nil machine, 'Status state machine should be registered'
  end
end
