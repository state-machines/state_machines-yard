# frozen_string_literal: true

require 'test_helper'
require 'state_machines/yard/renderer'

# Code conditions, reopened and inherited machines, code-valued state
# options and numeric names, documented as the core reads them
class ReviewTest < Minitest::Test
  include TestHelpers

  def setup
    setup_yard
    @log = StringIO.new
    @previous_log = [YARD::Logger.instance.io, YARD::Logger.instance.level]
    YARD::Logger.instance.io = @log
    YARD::Logger.instance.level = YARD::Logger::WARN # yardoc --quiet elsewhere raises it
  end

  def teardown
    YARD::Logger.instance.io, YARD::Logger.instance.level = @previous_log
    cleanup_yard
  end

  def test_a_code_condition_is_its_source_and_never_validated_as_a_string
    machines = parse_machines(<<~RUBY)
      class A
        state_machine :status, initial: :a do
          event(:go) { transition a: :b, if: -> { "system(" == "x" } }
        end
      end
    RUBY
    machine = machines['A'][:status]

    assert_equal(:'-> { "system(" == "x" }', machine.events[:go].branches.first.if_condition)
    assert_equal(['a -> b [if (-> { "system(" == "x" })]'],
                 StateMachines::Yard::Description.events(machine).first[:transitions])
  end

  def test_a_string_condition_the_core_refuses_is_reported_not_raised
    parse_code(<<~RUBY)
      class A
        state_machine :status, initial: :a do
          event(:go) { transition a: :b, if: "system('ls')" }
        end
      end
    RUBY

    assert_includes(YARD::Registry.at('A#go').docstring, 'Its transitions cannot be described')
  end

  def test_a_renderer_raising_a_security_error_leaves_the_diagram_out
    machine = parse_machines(<<~RUBY)['A'][:status]
      class A
        state_machine :status, initial: :a do
          event(:go) { transition a: :b, if: "system('ls')" }
        end
      end
    RUBY
    previous = ENV.fetch('STATE_MACHINES_RENDERER', nil)
    ENV['STATE_MACHINES_RENDERER'] = 'mermaid'

    assert_nil(StateMachines::Yard::Renderer.render(machine))
  ensure
    ENV['STATE_MACHINES_RENDERER'] = previous
  end

  def test_a_reopened_machine_is_extended
    machines = parse_machines(<<~RUBY)
      class B
        state_machine(:status, initial: :a) { event(:go) { transition a: :b } }
        state_machine(:status) { event(:stop) { transition b: :a } }
      end
    RUBY

    assert_equal(%i[go stop], machines['B'][:status].events.map(&:name))
    refute_includes(@log.string, 'NoMethodError')
  end

  def test_a_reopened_machine_takes_only_what_the_core_lets_it_change
    machines = parse_machines(<<~RUBY)
      class B
        state_machine(:status, initial: :a) { event(:go) { transition a: :b } }
        state_machine(:status, initial: :b)
        state_machine(:status, attribute: :other) { event(:never) { transition b: :a } }
      end
    RUBY
    machine = machines['B'][:status]

    assert_equal([:b], machine.states.select(&:initial?).map(&:name))
    assert_equal(%i[go], machine.events.map(&:name))
    assert_includes(@log.string, 'state machine is not documented')
  end

  REOPENED_WITH_AN_UNDRAWABLE_STATE = <<~RUBY
    class B
      state_machine(:status, initial: :a) { event(:go) { transition a: :b } }
      state_machine(:status) { event(:empty) { transition b: :"" } }
    end
  RUBY

  def test_a_reopened_machine_that_cannot_be_drawn_again_publishes_no_earlier_diagram
    %w[mermaid graphviz].each do |renderer|
      entry = with_renderer(renderer) do
        parse_code(REOPENED_WITH_AN_UNDRAWABLE_STATE)
        YARD::Registry.at('B')['state_machines'][:status]
      end

      assert_equal(%w[go empty], entry[:events].map { it[:name] }, renderer)
      next assert_empty(entry.slice(:mermaid, :image, :renderer), renderer) if renderer == 'mermaid'

      # GraphViz draws a state named "" (blank label): its diagram is the extended machine's
      assert_equal(:graphviz, entry[:renderer])
    end
    assert_includes(@log.string, 'the reopened status machine could not be drawn again')
  end

  def test_a_reopened_machine_is_drawn_again
    entry = with_renderer('mermaid') do
      parse_code(<<~RUBY)
        class B
          state_machine(:status, initial: :a) { event(:go) { transition a: :b } }
          state_machine(:status) { event(:stop) { transition b: :a } }
        end
      RUBY
      YARD::Registry.at('B')['state_machines'][:status]
    end

    assert_includes(entry[:mermaid], 'b --> a')
  end

  def test_a_subclass_machine_takes_its_own_options
    machines = parse_machines(<<~RUBY)
      class V
        state_machine(:status, initial: :parked) { event(:go) { transition parked: :moving } }
      end
      class Car < V
        state_machine(:status, initial: :moving)
      end
    RUBY

    assert_equal([:moving], machines['Car'][:status].states.select(&:initial?).map(&:name))
    assert_equal([:parked], machines['V'][:status].states.select(&:initial?).map(&:name))
  end

  def test_state_options_written_as_code_are_their_source
    machine = parse_machines(<<~RUBY)['C'][:status]
      class C
        state_machine :status, initial: :idle do
          state :idle, value: -> { 42 }, human_name: I18n.t('idle')
        end
      end
    RUBY
    idle = machine.states[:idle]

    assert_equal('-> { 42 }', idle.value(false).inspect)
    assert_equal("I18n.t('idle')", idle.human_name.to_s)
    assert_includes(@log.string, 'value: is code (`-> { 42 }`), documented as its source')
  end

  def test_numeric_names_are_names
    machine = parse_machines(<<~RUBY)['D'][:status]
      class D
        state_machine :status, initial: 1 do
          state 1, 2.5
          event(:go) { transition 1 => 2 }
        end
      end
    RUBY

    # 2.5 is refused by the core: every state name must be of one class
    assert_equal([1, 2], machine.states.map(&:name))
    assert_includes(@log.string, 'state is not documented: 2.5 state defined as Float')
    assert_equal([1], machine.states.select(&:initial?).map(&:name))
    assert_equal(1, machine.events[:go].branches.size)
  end

  def with_renderer(renderer)
    previous = ENV.fetch('STATE_MACHINES_RENDERER', nil)
    ENV['STATE_MACHINES_RENDERER'] = renderer
    YARD::Registry.clear
    yield
  ensure
    ENV['STATE_MACHINES_RENDERER'] = previous
  end

  def test_generated_methods_document_their_parameters
    parse_code('class E; state_machine(:status, initial: :a) { event(:go) { transition a: :b } }; end')

    refute_includes(@log.string, 'unknown parameter name')
    assert_equal([['state', nil]], YARD::Registry.at('E.human_status_name').parameters)
  end
end
