# frozen_string_literal: true

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

    refute_nil vehicle_class, 'Vehicle class should be registered'

    # Check for transitions documentation through the event methods
    ignite_method = YARD::Registry.at('Vehicle#ignite')

    refute_nil ignite_method, 'ignite method should be registered'
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

    refute_nil vehicle_class, 'Vehicle class should be registered'

    # The drive method should be registered
    drive_method = YARD::Registry.at('Vehicle#drive')

    refute_nil drive_method, 'drive method should be registered'
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

    refute_nil vehicle_class, 'Vehicle class should be registered'

    # The drive method should be registered despite the conditional
    drive_method = YARD::Registry.at('Vehicle#drive')

    refute_nil drive_method, 'drive method should be registered'
  end

  def test_transition_handler_preserves_static_guards
    code = <<-RUBY
      class Vehicle
        state_machine :gate, initial: :locked do
          event :unlock do
            transition locked: :unlocked
          end
        end

        state_machine :status, initial: :parked do
          event :drive do
            transition parked: :moving, if: :engine_started?, if_state: { gate: :unlocked }
          end
        end
      end
    RUBY

    branch = parse_machines(code)['Vehicle'][:status].events[:drive].branches.first

    assert_equal :engine_started?, branch.if_condition
    assert_equal({ if_state: { gate: :unlocked } }, branch.state_guards)
  end

  def test_transition_handler_with_special_matchers
    code = <<-RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          event :repair do
            # Use 'all' matcher
            transition any => :parked
          end
      #{'    '}
          event :maintain do
            # Use 'same' matcher
            transition all => same
          end
        end
      end
    RUBY

    parse_code(code)

    vehicle_class = YARD::Registry.at('Vehicle')

    refute_nil vehicle_class, 'Vehicle class should be registered'

    # Both methods should be registered
    repair_method = YARD::Registry.at('Vehicle#repair')

    refute_nil repair_method, 'repair method should be registered'

    maintain_method = YARD::Registry.at('Vehicle#maintain')

    refute_nil maintain_method, 'maintain method should be registered'
  end

  # Every literal the core refuses as a transition's callback, bare, in an
  # Array or inside parentheses or begin/end, leaves the transition out
  def test_literals_that_are_no_method_leave_the_transition_out_however_written
    values = ['(nil)', '(1)', '(false)', '(true)', '(1.5)', '({ log: true })', '/x/', "/x\#{y}/", '1r', '2i',
              '-1', '1..2', '__LINE__', '__ENCODING__', '()', 'begin end', 'begin; nil; end', '((nil))',
              '[[:a]]', '[(nil), :x]']
    body = values.map.with_index { |value, index| "event(:e#{index}) { transition parked: :idling, after: #{value} }" }
    body << 'event(:kept) { transition parked: :idling, after: :kept }'

    assert_equal([[[:after, [:kept]]]], own_callbacks(body.join("\n")))
  end

  def test_a_group_of_one_expression_is_that_expression
    found = own_callbacks(<<~RUBY)
      event :ignite do
        transition parked: :idling, after: ((:log))
        transition parked: :stalled, before: (-> { tow })
        transition parked: :broken, around: (%i[a b]), after: [(:c), begin :d end]
        transition idling: :parked, after: (:a; :b)
      end
    RUBY

    assert_equal([[[:after, [:log]]], [[:before, ['lambda@(stdin):6']]],
                  [[:around, %i[a b]], [:after, %i[c d]]], [[:after, ['(:a; :b)']]]], found)
  end

  def test_a_transition_in_a_state_block_is_documented
    code = <<~RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          state :idling do
            transition to: :parked, on: :park, if: :stopped?
          end
        end
      end
    RUBY

    branch = parse_machines(code)['Vehicle'][:status].events[:park].branches.first
    requirement = branch.state_requirements.first

    assert_equal([[:idling], [:parked], :stopped?],
                 [requirement[:from].values, requirement[:to].values, branch.if_condition])
  end

  # A transition's own callbacks, by branch, as [type, methods]
  def own_callbacks(body)
    code = <<~RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          state :stalled, :broken
      #{body.gsub(/^/, '    ')}
        end
      end
    RUBY
    machine = parse_machines(code)['Vehicle'][:status]
    machine.events.flat_map(&:branches).map { |branch| branch.callbacks.map { [it.type, it.callables] } }
  end

  def test_a_transitions_own_callbacks_are_its_methods
    found = own_callbacks(<<~RUBY)
      event :ignite do
        transition parked: :idling, before: :prime, around: [:crank, 'time_it'], after: %i[log_start warm_up]
      end
      state :idling do
        transition to: :parked, on: :park, after: :set_brake
      end
    RUBY

    assert_equal([[[:before, [:prime]], [:around, [:crank, 'time_it']], [:after, %i[log_start warm_up]]],
                  [[:after, [:set_brake]]]], found)
  end

  def test_own_callbacks_written_as_code_are_methods_not_states
    found = own_callbacks(<<~RUBY)
      event :ignite do
        transition parked: :idling, after: -> { tow }
        transition parked: :stalled, before: [:prime, lambda { crank }], around: notifier
        transition parked: :broken, after: method(:report)
      end
    RUBY

    assert_equal([[[:after, ['lambda@(stdin):5']]],
                  [[:before, [:prime, 'lambda@(stdin):6']], [:around, ['notifier']]],
                  [[:after, ['method(:report)']]]], found)
  end

  def test_own_callbacks_the_core_refuses_leave_the_transition_out
    found = own_callbacks(<<~RUBY)
      event :ignite do
        transition parked: :idling, after: nil
        transition parked: :idling, before: [:prime, 1]
        transition parked: :idling, around: []
        transition parked: :idling, after: { log: true }
        transition parked: :idling, do: :log
        transition parked: :stalled, after: :kept
      end
    RUBY

    assert_equal([[[:after, [:kept]]]], found)
  end
end
