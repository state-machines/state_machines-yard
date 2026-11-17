# frozen_string_literal: true

require 'test_helper'

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
