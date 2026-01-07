# frozen_string_literal: true

require 'stringio'

module StateMachines
  module Yard
    module Renderer
      module_function

      def selection
        env = ENV['STATE_MACHINES_RENDERER']
        return env.to_sym if %w[graphviz mermaid none].include?(env)

        :none
      end

      def render(machine)
        case selection
        when :graphviz
          render_graphviz(machine)
        when :mermaid
          render_mermaid(machine)
        else
          nil
        end
      end

      def render_graphviz(machine)
        require 'tempfile'
        require 'state_machines/graphviz'

        file = Tempfile.new(['state_machine', '.png'])
        begin
          if machine.draw(name: File.basename(file.path, '.png'),
                         path: File.dirname(file.path),
                         orientation: 'landscape')
            return { image: file.read }
          end
        ensure
          file.close
          file.unlink
        end

        nil
      rescue LoadError
        nil
      end

      def render_mermaid(machine)
        require 'state_machines/mermaid'

        io = StringIO.new
        StateMachines::Mermaid::Renderer.draw_machine(machine, io: io)
        mermaid = io.string
        return nil if mermaid.nil? || mermaid.strip.empty?

        { mermaid: mermaid }
      rescue LoadError
        nil
      end
    end
  end
end
