# frozen_string_literal: true

require 'stringio'
require 'tmpdir'

module StateMachines
  module Yard
    # Draws a documented machine with the renderer STATE_MACHINES_RENDERER
    # names (graphviz, mermaid or none), guards included
    module Renderer
      module_function

      def selection
        env = ENV.fetch('STATE_MACHINES_RENDERER', nil)
        return env.to_sym if %w[graphviz mermaid none].include?(env)

        :none
      end

      # The diagram, or nil. A renderer that fails on a machine leaves its
      # diagram out with a warning; the rest of its documentation stands.
      def render(machine)
        case selection
        when :graphviz then render_graphviz(machine)
        when :mermaid then render_mermaid(machine)
        end
      rescue StandardError => e
        log.warn "state_machines-yard: no #{selection} diagram for #{machine.owner_class} #{machine.name}: " \
                 "#{e.class}: #{e.message}"
        nil
      end

      # The machine as a PNG. Drawn with the GraphViz renderer itself:
      # Machine#draw goes through whichever renderer is global.
      def render_graphviz(machine)
        require 'state_machines/graphviz'

        Dir.mktmpdir('state_machines-yard') do |dir|
          graph = StateMachines::Graphviz::Renderer.draw_machine(
            machine, name: 'state_machine', path: dir, format: 'png', orientation: 'landscape'
          )
          { image: File.binread(graph.file_path) }
        end
      rescue LoadError
        nil
      end

      def render_mermaid(machine)
        require 'state_machines-mermaid'

        io = StringIO.new
        StateMachines::Mermaid::Renderer.draw_machine(machine, io: io, show_conditions: true, show_callbacks: true)
        mermaid = io.string
        return nil if mermaid.strip.empty?

        { mermaid: mermaid }
      rescue LoadError
        nil
      end
    end
  end
end
