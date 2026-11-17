# frozen_string_literal: true

require_relative '../renderer'

module StateMachines
  module Yard
    module Handlers
      # Handles and processes #state_machine
      class Machine < Base
        handles method_call(:state_machine)
        namespace_only

        # Store the handled method name for testing
        @handles_method = :state_machine

        # What a renderer adds to a machine's entry
        DIAGRAM_KEYS = %i[image mermaid renderer].freeze

        # Stands for an initial state the documented code computes
        DYNAMIC_INITIAL_STATE = ->(_object) {}

        # The generated state machine
        attr_reader :machine

        def process
          name # A machine whose name is code is not documented

          # A machine the class already documents is reopened, as the core
          # does. Given a block, even an empty one, the core copies an
          # inherited machine for the subclass instead of extending the
          # superclass's, and applies the subclass's options to the copy.
          @machine = (reopened_machine&.owner_class || owner_class).state_machine(name, options) do
            # The statement's block is parsed below
          end

          track_machine

          # Parse the block
          parse_block(statement.block.last, owner: machine) if statement.block

          document_events
          document_diagram

          # Define auto-generated methods
          define_macro_methods
          define_state_methods
          define_event_methods
        rescue Unreadable, ArgumentError => e
          # A machine the core refuses (an option a reopened machine cannot
          # change) is not documented as something else
          skip('state machine', e)
        end

        protected

        # The class the documented machine is built on: a subclass of the
        # inherited machine's owner, so the machine extends that one. It is
        # named as the documented class, which diagrams show in their title.
        def owner_class
          klass = inherited_machine ? Class.new(inherited_machine.owner_class) : Class.new { extend MacroMethods }
          path = namespace.path
          klass.define_singleton_method(:name) { path }
          klass.define_singleton_method(:to_s) { path }
          klass
        end

        # The machine this class already documents under the name, if any
        def reopened_machine
          globals.state_machines&.dig(namespace.path, name)
        end

        # Stores the machine across files (subclasses find it there) and on
        # the documented class
        def track_machine
          globals.state_machines ||= Hash.new { |h, k| h[k] = {} }
          globals.state_machines[namespace.path][name] = machine
          namespace['state_machines'] ||= {}
          entry = namespace['state_machines'][name] ||= { name: name }
          entry[:description] = statement.docstring unless statement.docstring.to_s.empty? && entry[:description]
        end

        # The events' transitions, guards and callbacks as text, whatever
        # renderer draws the diagram
        def document_events
          @events = Description.events(machine).to_h { [it[:name], it] }
          namespace['state_machines'][name][:events] = @events.values
        end

        # The machine's diagram, drawn by the selected renderer
        # A reopened machine is drawn again: its previous diagram shows only
        # what was declared before, so it is never kept in place of a new one
        def document_diagram
          entry = namespace['state_machines'][name]
          stale = entry.slice(*DIAGRAM_KEYS)
          DIAGRAM_KEYS.each { entry.delete(it) }
          render = Renderer.render(machine)
          return entry.merge!(render, renderer: Renderer.selection) if render

          warn_stale_diagram unless stale.except(:renderer).empty?
        end

        def warn_stale_diagram
          log.warn "state_machines-yard: the reopened #{name} machine could not be drawn again; " \
                   "its earlier diagram is left out (#{parser.file}:#{statement.line})"
        end

        # The machine's name: its first argument, :state when there is none
        def name
          @name ||= begin
            argument = positional_arguments.first
            argument ? name_literal(argument) : :state
          end
        end

        # The machine options documentation depends on. Note that this will
        # only extract a subset of the options supported. An initial state
        # written as code is decided when the object is created, so no state
        # is documented as the initial one.
        def options
          @options ||= begin
            options = literal_options(%i[initial attribute namespace action])
            options[:initial] = DYNAMIC_INITIAL_STATE if dynamic_initial_state?
            options
          end
        end

        def dynamic_initial_state?
          option_pairs.any? do |key, value|
            literal(key) == :initial && begin
              literal(value)
              false
            rescue Unreadable
              true
            end
          end
        end

        # Gets the machine that was inherited from a superclass.  This also
        # ensures each ancestor has been loaded prior to looking up their definitions.
        def inherited_machine
          @inherited_machine ||= begin
            namespace.inheritance_tree.each do |ancestor|
              ensure_loaded!(ancestor)
            rescue YARD::Handlers::NamespaceMissingError
              # Ignore: just means that we can't access an ancestor
            end

            # Find the first ancestor that has the machine
            loaded_superclasses.find do |superclass|
              if superclass != namespace
                machine = globals.state_machines[superclass.path][name]
                break machine if machine
              end
            end
          end
        end

        # Gets members of this class's superclasses have already been loaded
        # by YARD
        def loaded_superclasses
          namespace.inheritance_tree.grep(YARD::CodeObjects::ClassObject)
        end

        # Gets a list of all attributes for the current class, including those
        # that are inherited
        def instance_attributes
          attributes = {}
          loaded_superclasses.each { |superclass| attributes.merge!(superclass.instance_attributes) }
          attributes
        end

        # Gets the type of ORM integration being used based on the list of
        # ancestors (including mixins)
        def integration
          @integration ||= Integrations.match_ancestors(namespace.inheritance_tree(true).map(&:path))
        end

        # Gets the class type being used to define states.  Default is "Symbol".
        def state_type
          @state_type ||= if machine.states.any?
                            machine.states.filter_map(&:name).first.class.to_s
                          else
                            'Symbol'
                          end
        end

        # Gets the class type being used to define events.  Default is "Symbol".
        def event_type
          @event_type ||= machine.events.any? ? machine.events.first.name.class.to_s : 'Symbol'
        end

        # Registers a method the machine generates, with its documentation
        def document_method(name, docstring, parameters: nil, scope: :instance)
          method = YARD::CodeObjects::MethodObject.new(namespace, name, scope)
          register(method)
          # YARD checks @param tags against the parameters, as [name, default]
          # pairs, when the docstring is set
          method.parameters = parameters.map { |name, default| [name, default] } if parameters
          method.docstring = docstring
          method
        end

        # Registers an attribute's reader and writer
        def document_attribute(attribute, description)
          namespace.attributes[:instance][attribute] = {
            read: document_method(attribute, ["Gets the current #{description} for the machine",
                                              "@return The #{description}"]),
            write: document_method("#{attribute}=", ['Sets the current value for the machine',
                                                     "@param new_#{attribute} The new value to set"],
                                   parameters: ["new_#{attribute}"])
          }
        end

        # Defines auto-generated macro methods for the given machine. A
        # subclass's machine extends its superclass's, so the methods that
        # read the current state are documented on it too; the attributes and
        # the methods that list or fire events are the superclass's.
        def define_macro_methods
          define_human_name_methods
          define_state_reader_methods
          return if inherited_machine

          define_attribute_methods
          define_event_list_methods
        end

        def define_human_name_methods
          document_method("human_#{machine.attribute(:name)}",
                          ['Gets the humanized name for the given state.',
                           "@param [#{state_type}] state The state to look up",
                           '@return [String] The human state name'],
                          parameters: ['state'], scope: :class)
          document_method("human_#{machine.attribute(:event_name)}",
                          ['Gets the humanized name for the given event.',
                           "@param [#{event_type}] event The event to look up",
                           '@return [String] The human event name'],
                          parameters: ['event'], scope: :class)
        end

        def define_state_reader_methods
          document_method("#{machine.name}?",
                          ['Checks the given state name against the current state.',
                           "@param [#{state_type}] state_name The name of the state to check",
                           '@return [Boolean] True if they are the same state, otherwise false',
                           '@raise [IndexError] If the state name is invalid'],
                          parameters: ['state_name'])
          document_method(machine.attribute(:name),
                          ['Gets the internal name of the state for the current value.',
                           "@return [#{state_type}] The internal name of the state"])
          document_method("human_#{machine.attribute(:name)}",
                          ['Gets the human-readable name of the state for the current value.',
                           '@return [String] The human-readable state name'])
        end

        # Only register attributes when the accessor isn't explicitly defined
        # by the class / superclass *and* isn't defined by inference from the
        # ORM being used
        def define_attribute_methods
          unless integration || instance_attributes.include?(machine.attribute.to_sym)
            document_attribute(machine.attribute, 'attribute value')
          end
          document_attribute("#{machine.name}_event", 'event attribute value') if action?
        end

        # Whether the machine has an action, its own or its integration's
        def action?
          options.include?(:action) ? options[:action] : integration&.defaults&.[](:action)
        end

        def define_event_list_methods
          requirements = ['@param [Hash] requirements The transition requirements to test against']
          guard = '@option requirements [Boolean] :guard Whether to guard transitions with conditionals'
          from_to_on = ["@option requirements [#{state_type}] :from (the current state) One or more initial states",
                        "@option requirements [#{state_type}] :to One or more target states",
                        "@option requirements [#{event_type}] :on One or more events that fire the transition"]

          document_method(machine.attribute(:events),
                          ["Gets the list of events that can be fired on the current #{machine.name} " \
                           '(uses the *unqualified* event names)', *requirements, *from_to_on, guard,
                           "@return [Array<#{event_type}>] The list of event names"],
                          parameters: [%w[requirements {}]])
          document_method(machine.attribute(:transitions),
                          ["Gets the list of transitions that can be made for the current #{machine.name}",
                           *requirements, *from_to_on, guard,
                           '@return [Array<StateMachines::Transition>] The available transitions'],
                          parameters: [%w[requirements {}]])
          define_path_and_fire_methods(requirements, guard)
        end

        def define_path_and_fire_methods(requirements, guard)
          document_method(machine.attribute(:paths),
                          ["Gets the list of sequences of transitions that can be run for the current #{machine.name}",
                           *requirements,
                           "@option requirements [#{state_type}] :from (the current state) The initial state",
                           "@option requirements [#{state_type}] :to The target state",
                           '@option requirements [Boolean] :deep Whether to enable deep searches for the target state',
                           guard, '@return [StateMachines::PathCollection] The collection of paths'],
                          parameters: [%w[requirements {}]])
          document_method("fire_#{machine.attribute(:event)}",
                          ["Fires an arbitrary #{machine.name} event with the given argument list",
                           "@param [#{event_type}] event The name of the event to fire",
                           '@param args Optional arguments to include in the transition',
                           '@return [Boolean] +true+ if the event succeeds, otherwise +false+'],
                          parameters: ['event', '*args'])
        end

        # Defines auto-generated event methods for the given machine
        def define_event_methods
          machine.events.each do |event|
            next if inherited_machine&.events&.[](event.name)

            define_event_query_methods(event)
            define_event_fire_methods(event)
          end
        end

        def define_event_query_methods(event)
          requirements = ['@param [Hash] requirements The transition requirements to test against',
                          "@option requirements [#{state_type}] :from One or more initial states",
                          "@option requirements [#{state_type}] :to One or more target states",
                          '@option requirements [Boolean] :guard Whether to guard transitions with conditionals']

          document_method("can_#{event.qualified_name}?",
                          ["Checks whether #{event.name.inspect} can be fired.", *requirements,
                           "@return [Boolean] +true+ if #{event.name.inspect} can be fired, otherwise +false+"],
                          parameters: [%w[requirements {}]])
          document_method("#{event.qualified_name}_transition",
                          ["Gets the next transition that would be performed if #{event.name.inspect} " \
                           'were to be fired.', *requirements,
                           '@return [StateMachines::Transition] The transition that would be performed or +nil+'],
                          parameters: [%w[requirements {}]])
        end

        def define_event_fire_methods(event)
          args = '@param [Array] args Optional arguments to include in transition callbacks'

          description = Description.docstring_lines(@events.fetch(event.name.to_s))

          document_method(event.qualified_name,
                          ["Fires the #{event.name.inspect} event.", *description, args,
                           '@return [Boolean] +true+ if the transition succeeds, otherwise +false+'],
                          parameters: ['*args'])
          document_method("#{event.qualified_name}!",
                          ["Fires the #{event.name.inspect} event, raising an exception if it fails.", *description,
                           args,
                           '@return [Boolean] +true+ if the transition succeeds',
                           '@raise [StateMachines::InvalidTransition] If the transition fails'],
                          parameters: ['*args'])
        end

        # Defines auto-generated state methods for the given machine
        def define_state_methods
          machine.states.each do |state|
            next if inherited_machine&.states&.[](state.name) || !state.name

            document_method("#{state.qualified_name}?",
                            ["Checks whether #{state.name.inspect} is the current state.",
                             '@return [Boolean] +true+ if this is the current state, otherwise +false+'])
          end
        end
      end
    end
  end
end
