# frozen_string_literal: true

require 'test_helper'
require 'state_machines/yard/renderer'

# The documented machine carries each transition callback with its methods,
# the transitions it runs on and its own conditions, read from literals only
class CallbackHandlerTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def machine(body)
    code = <<~RUBY
      class Vehicle
        state_machine :status, initial: :parked do
          #{body}
          event(:ignite) { transition parked: :idling }
          event(:park) { transition idling: :parked }
        end
      end
    RUBY
    parse_machines(code)['Vehicle'][:status]
  end

  def callbacks(body)
    machine(body).callbacks.values.flatten.map do |callback|
      branch = callback.branch
      requirement = branch.state_requirements.first
      { type: callback.type, methods: callback.callables,
        from: [requirement[:from].class, requirement[:from].values],
        to: [requirement[:to].class, requirement[:to].values],
        on: branch.event_requirement.values, if: branch.if_condition, unless: branch.unless_condition,
        state_guards: branch.state_guards }
    end
  end

  def test_each_kind_is_documented
    found = callbacks(<<~RUBY)
      before_transition do: :check_mirrors
      after_transition do: :log
      around_transition do: :time
      after_failure do: :alert
    RUBY

    assert_equal(%i[before around after failure], found.map { it[:type] })
    assert_equal([[:check_mirrors], [:time], [:log], [:alert]], found.map { it[:methods] })
  end

  def test_requirements_are_read_as_for_a_transition
    found = callbacks(<<~RUBY).to_h { [it[:methods].first, it] }
      before_transition from: :parked, to: [:idling, nil], on: :ignite, do: :a
      after_transition parked: :idling, do: :b
      after_transition except_to: :parked, except_on: :park, do: :c
      before_transition all - [:parked] => same, do: :d
    RUBY

    assert_equal([StateMachines::WhitelistMatcher, [:parked]], found[:a][:from])
    assert_equal([StateMachines::WhitelistMatcher, [:idling, nil]], found[:a][:to])
    assert_equal([:ignite], found[:a][:on])
    assert_equal([[StateMachines::WhitelistMatcher, [:parked]], [StateMachines::WhitelistMatcher, [:idling]]],
                 [found[:b][:from], found[:b][:to]])
    assert_equal([[StateMachines::AllMatcher, []], [StateMachines::BlacklistMatcher, [:parked]], [:park]],
                 [found[:c][:from], found[:c][:to], found[:c][:on]])
    assert_equal([[StateMachines::BlacklistMatcher, [:parked]], [StateMachines::LoopbackMatcher, []]],
                 [found[:d][:from], found[:d][:to]])
  end

  def test_conditions_and_state_guards_are_kept
    callback = callbacks(<<~RUBY).first
      before_transition on: :ignite, do: :log, if: [:logging?, 'verbose'], unless: -> { quiet? },
                        if_any_state: { alarm: :off, gate: nil }
    RUBY

    assert_equal([:logging?, 'verbose'], callback[:if])
    assert_equal(:'-> { quiet? }', callback[:unless])
    assert_equal({ if_any_state: { alarm: :off, gate: nil } }, callback[:state_guards])
  end

  def test_methods_are_read_as_the_core_reads_them
    callback = callbacks(<<~RUBY).first
      before_transition :first, 'second(self)', on: :ignite, do: [:third, -> { fourth }, lambda { fifth }, notifier] do |vehicle|
        vehicle.sixth
      end
    RUBY

    assert_equal([:first, 'second(self)', :third, 'lambda@(stdin):3', 'lambda@(stdin):3', 'notifier',
                  'lambda@(stdin):3'], callback[:methods])
  end

  def test_a_block_argument_is_a_method
    assert_equal([:lock, '&:beep'], callbacks('before_transition on: :park, do: :lock, &:beep').first[:methods])
  end

  def test_options_on_how_a_callback_runs_are_not_requirements
    callback = callbacks('before_transition on: :park, do: :lock, bind_to_object: true, terminator: nil').first

    assert_equal([StateMachines::AllMatcher, []], callback[:from])
    assert_equal([:lock], callback[:methods])
  end

  def test_a_callback_the_core_refuses_or_written_as_code_is_left_out
    found = callbacks(<<~RUBY)
      after_failure from: :parked, do: :alert
      after_transition to: STATES, do: :log
      before_transition from: :parked
      before_transition from: :parked, do: :kept
    RUBY

    assert_equal([[:kept]], found.map { it[:methods] })
  end

  def test_the_mermaid_diagram_shows_the_callbacks
    machine = machine('before_transition on: :park, do: :lock')

    mermaid = StateMachines::Yard::Renderer.render_mermaid(machine)[:mermaid]

    assert_includes(mermaid, 'before lock')
  end

  def test_a_renderer_that_fails_leaves_the_diagram_out
    machine = machine('')
    machine.instance_variable_set(:@events, nil)
    previous = ENV.fetch('STATE_MACHINES_RENDERER', nil)
    ENV['STATE_MACHINES_RENDERER'] = 'mermaid'

    assert_nil(StateMachines::Yard::Renderer.render(machine))
  ensure
    ENV['STATE_MACHINES_RENDERER'] = previous
  end
end
