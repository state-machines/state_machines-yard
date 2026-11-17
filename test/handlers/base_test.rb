# frozen_string_literal: true

require 'test_helper'

class BaseHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def test_symbol_state_name
    code = <<-RUBY
      class TestClass
        state_machine :status do
          # Test using a symbol
          state :parked
        end
      end
    RUBY

    parse_code(code)

    # The name was read from the symbol literal
    test_class = YARD::Registry.at('TestClass')

    refute_nil test_class, 'TestClass should be registered'

    parked_method = YARD::Registry.at('TestClass#parked?')

    refute_nil parked_method, 'parked? method should be registered'
  end

  def test_string_state_name
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

    refute_nil test_class, 'TestClass should be registered'

    moving_method = YARD::Registry.at('TestClass#moving?')

    refute_nil moving_method, 'moving? method should be registered'
  end

  def test_several_state_names
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

    refute_nil test_class, 'TestClass should be registered'

    %w[parked idling moving].each do |state|
      method = YARD::Registry.at("TestClass##{state}?")

      refute_nil method, "#{state}? method should be registered"
    end
  end

  # YARD's parser ends a statement before a trailing rational or imaginary
  # literal and past a trailing negative number; each call is read whole
  def test_a_call_ending_in_any_number_is_read_whole
    machine = parse_machines(<<~RUBY)['Vehicle'][:status]
      class Vehicle # é
        state_machine :status, initial: :parked do
          state :parked, value: 1r
          state :idling, value: 2i
          state :stalled, value: -1
          event(:ignite) { transition parked: :idling, if: 3r }
        end
      end
    RUBY

    assert_equal(%w[1r 2i -1], machine.states.map { it.value(false).inspect })
    assert_equal(:'3r', machine.events[:ignite].branches.first.if_condition)
  end
end
