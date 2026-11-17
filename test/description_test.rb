# frozen_string_literal: true

require 'test_helper'
require 'state_machines/yard/renderer'

# The generated documentation lists each event's transitions, guards and
# callbacks as text whichever renderer draws the diagram, or none
class DescriptionTest < Minitest::Test
  include TestHelpers

  CODE = <<~RUBY
    class Vehicle
      state_machine :status, initial: :parked do
        before_transition from: :parked, do: :check_mirrors
        after_transition to: :idling, do: :log_start, if: :logging?
        after_failure on: :ignite, do: :alert

        event :ignite do
          transition parked: :idling, if: :engine_ok?, if_any_state: { gate: :open, alarm: :off }
          transition parked: :stalled
          transition parked: :never
        end

        event :noop
      end
    end
  RUBY

  IGNITE = [
    'parked -> idling [if engine_ok? && if_any_state (gate=open, alarm=off)] / before check_mirrors, ' \
    'after log_start (if logging?)',
    'parked -> stalled / before check_mirrors'
  ].freeze

  DIAGRAMS = { 'none' => [], 'graphviz' => ['img'], 'mermaid' => ['pre.mermaid'] }.freeze

  def setup
    setup_yard
    @previous_renderer = ENV.fetch('STATE_MACHINES_RENDERER', nil)
  end

  def teardown
    ENV['STATE_MACHINES_RENDERER'] = @previous_renderer
    cleanup_yard
  end

  def document(renderer)
    ENV['STATE_MACHINES_RENDERER'] = renderer
    YARD::Registry.clear
    parse_code(CODE)
    YARD::CLI::Yardoc.run('--no-save', '--no-progress', '--quiet', '-o', @yard_dir)
    Nokogiri::HTML(File.read(File.join(@yard_dir, 'Vehicle.html')))
  end

  def test_each_renderer_mode_documents_the_events_as_text
    DIAGRAMS.each do |renderer, diagram|
      html = document(renderer)
      events = html.css('dl.state_machine_events')

      assert_equal(%w[ignite noop], events.css('dt').map { it.text.strip }, renderer)
      assert_equal(IGNITE, events.css('dd').first.css('li').map { it.text.strip }, renderer)
      assert_includes(events.css('dd').first.text, 'On failure: alert', renderer)
      assert_includes(events.css('dd').last.text, 'No transitions: it never fires.', renderer)
      assert_equal(diagram.size, diagram.sum { html.css(it).size }, renderer)
    end
  end

  def test_callbacks_read_in_the_order_the_core_runs_them
    machine = parse_machines(<<~RUBY)['Lamp'][:state]
      class Lamp
        state_machine initial: :off do
          around_transition on: :switch, do: :hold
          before_transition from: :off, do: :check
          after_transition do: :log
          around_transition on: :switch, do: :time
          event(:switch) { transition off: :on }
        end
      end
    RUBY

    assert_equal(['off -> on / around hold, before check, around time, after log'],
                 StateMachines::Yard::Description.events(machine).first[:transitions])
  end

  LAMP = <<~RUBY
    class Lamp
      state_machine initial: :off do
        before_transition do: :check
        around_transition do: :hold
        before_transition on: :switch, do: :warm, if: :cold?
        after_transition do: :log
        state :dim
        event :switch do
          transition off: :lit, if: :bulb?, before: :prime, around: :fade, after: [:glow, -> { hum }]
          transition off: :dim, after: :flicker
          transition lit: same, around: :pulse
        end
        state :lit do
          transition to: :off, on: :cut, around: :fade, before: :cool
        end
      end
    end
  RUBY

  def test_a_transitions_own_callbacks_read_where_the_core_runs_them
    switch, cut = StateMachines::Yard::Description.events(parse_machines(LAMP)['Lamp'][:state])

    assert_equal(['off -> lit [if bulb?] / before check, around hold, before warm (if cold?), before prime, ' \
                  'around fade, after glow, after lambda@(stdin):9, after log',
                  'off -> dim / before check, around hold, before warm (if cold?), after flicker, after log',
                  'lit -> lit / before check, around hold, before warm (if cold?), around pulse, after log'],
                 switch[:transitions])
    # a state context transition, its around: written before its before:
    assert_equal(['lit -> off / before check, around hold, around fade, before cool, after log'], cut[:transitions])
  end

  def test_the_mermaid_diagram_shows_a_transitions_own_callbacks
    mermaid = StateMachines::Yard::Renderer.render_mermaid(parse_machines(LAMP)['Lamp'][:state])[:mermaid]

    assert_includes(mermaid, 'lit --> off : cut / before check, around hold, around fade, before cool, after log')
  end

  def test_each_renderer_mode_documents_the_event_methods
    DIAGRAMS.each_key do |renderer|
      document(renderer)
      ignite = YARD::Registry.at('Vehicle#ignite').docstring
      ignite_bang = YARD::Registry.at('Vehicle#ignite!').docstring

      [ignite, ignite_bang].each do |docstring|
        IGNITE.each { assert_includes(docstring, "* #{it}", renderer) }

        assert_includes(docstring, 'On failure: alert', renderer)
      end
      assert_includes(YARD::Registry.at('Vehicle#noop').docstring, 'No transitions: it never fires.', renderer)
      assert_equal(['@param', '@return'], YARD::Registry.at('Vehicle#ignite').tags.map { "@#{it.tag_name}" })
    end
  end
end
