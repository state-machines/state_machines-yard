# frozen_string_literal: true

require 'test_helper'
require 'state_machines/yard/renderer'

# The documented machine carries the guards and requirements the core runs,
# read from literals only
class GuardsTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
  end

  def teardown
    cleanup_yard
  end

  def machine(body, options = 'initial: :parked')
    code = <<~RUBY
      module Fleet
        class Vehicle
          state_machine :status, #{options} do
            #{body}
          end
        end
      end
    RUBY
    parse_machines(code)['Fleet::Vehicle'][:status]
  end

  def branches(body)
    machine("event :go do\n#{body}\nend").events[:go].branches
  end

  def test_every_state_guard_kind_keeps_its_group
    kinds = %i[if_state unless_state if_all_states unless_all_states if_any_state unless_any_state]
    body = kinds.map { "transition parked: :moving, #{it}: { gate: :open, alarm: nil }" }.join("\n")

    guards = branches(body).map(&:state_guards)

    assert_equal(kinds.map { { it => { gate: :open, alarm: nil } } }, guards)
  end

  def test_state_guards_with_string_keys_and_names
    branch = branches("transition parked: :moving, if_state: { 'gate' => 'open' }").first

    assert_equal({ if_state: { 'gate' => 'open' } }, branch.state_guards)
  end

  def test_array_conditions_keep_each_condition
    branch = branches("transition parked: :moving, if: [:a?, 'b && c'], unless: %i[d? e?]").first

    assert_equal([:a?, 'b && c'], branch.if_condition)
    assert_equal(%i[d? e?], branch.unless_condition)
  end

  def test_a_string_condition_is_the_code_it_holds
    branch = branches(%q(transition parked: :moving, if: "speed > 0 && gear != 'R'")).first

    assert_equal("speed > 0 && gear != 'R'", branch.if_condition)
  end

  def test_a_condition_written_as_code_is_documented_by_its_source
    first, second = branches(<<~RUBY)
      transition parked: :moving, if: -> { warm? }
      transition parked: :idling, unless: [:cold?, engine.stalled?]
    RUBY

    assert_equal(:'-> { warm? }', first.if_condition)
    assert_equal(%i[cold? engine.stalled?], second.unless_condition)
  end

  def test_a_dynamic_condition_is_never_read_as_a_state_matcher
    branch = branches('transition parked: :moving, if: all').first

    assert_equal(:all, branch.if_condition)
  end

  def test_false_and_nil_are_no_condition
    first, second = branches(<<~RUBY)
      transition parked: :moving, if: false
      transition idling: :moving, unless: nil
    RUBY

    refute(first.if_condition)
    assert_nil(second.unless_condition)
  end

  def test_a_transition_with_a_state_guard_written_as_code_is_left_out
    branches = branches(<<~RUBY)
      transition parked: :moving, if_state: GATE_OPEN
      transition parked: :idling
    RUBY

    requirements = branches.map { it.state_requirements.first }

    assert_equal([[[:parked], [:idling]]], requirements.map { |req| [req[:from].values, req[:to].values] })
  end

  def test_a_transition_the_core_refuses_is_left_out
    assert_empty(branches('transition parked: :moving, if_state: {}'))
  end

  def test_requirements_written_as_code_leave_the_transition_out
    assert_empty(branches('transition STATES => :parked'))
  end

  def test_matchers_and_names
    first, second, third = branches(<<~RUBY)
      transition all - [:moving, nil] => :parked
      transition any => same
      transition :"hard stop" => nil
    RUBY

    assert_instance_of(StateMachines::BlacklistMatcher, first.state_requirements.first[:from])
    assert_equal([:moving, nil], first.state_requirements.first[:from].values)
    assert_instance_of(StateMachines::AllMatcher, second.state_requirements.first[:from])
    assert_instance_of(StateMachines::LoopbackMatcher, second.state_requirements.first[:to])
    assert_equal([:'hard stop', nil], third.known_states)
  end

  def test_machine_options_are_read
    machine = machine('', "initial: :parked, attribute: :status_code, namespace: 'car'")

    assert_equal([:parked], machine.states.select(&:initial?).map(&:name))
    assert_equal(:status_code, machine.attribute)
    assert_equal('car', machine.namespace)
  end

  def test_an_initial_state_written_as_code_is_dynamic
    machine = machine('state :parked', 'initial: -> { :parked }')

    assert_predicate(machine, :dynamic_initial_state?)
    assert_empty(machine.states.select(&:initial?))
  end

  def test_state_and_event_options_are_not_names
    machine = machine(<<~RUBY)
      state :parked, value: 1, human_name: 'Parked'
      state :idling, value: Time.now
      event :"odd name", human_name: 'Odd' do
        transition parked: :idling
      end
    RUBY

    assert_equal([[:parked, 1, 'Parked'], [:idling, 'idling', 'idling']],
                 machine.states.map { [it.name, it.value(false), it.human_name] })
    assert_equal([[:'odd name', 'Odd']], machine.events.map { [it.name, it.human_name] })
  end

  def test_the_mermaid_diagram_shows_the_guards
    machine = machine(<<~RUBY)
      event :drive do
        transition parked: :moving, if: :engine_started?, if_any_state: { gate: :open, alarm: :off }
      end
    RUBY

    mermaid = StateMachines::Yard::Renderer.render_mermaid(machine)[:mermaid]

    assert_includes(mermaid, 'drive [if engine_started? #38;#38; if_any_state (gate=open, alarm=off)]')
  end

  def test_the_documented_machine_is_owned_by_the_documented_class
    assert_equal('Fleet::Vehicle', machine('').owner_class.name)
  end

  def test_the_graphviz_diagram_is_a_png_drawn_by_graphviz
    previous = StateMachines::Machine.renderer
    StateMachines::Machine.renderer = StateMachines::STDIORenderer
    machine = machine('event(:drive) { transition parked: :moving }')

    image = StateMachines::Yard::Renderer.render_graphviz(machine)[:image]

    assert_equal("\x89PNG".b, image.byteslice(0, 4))
  ensure
    StateMachines::Machine.renderer = previous
  end
end
