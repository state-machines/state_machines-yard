module StateMachines
  module Yard
    module Handlers
      # Handles and processes #state_machine
      class Machine < Base
        handles method_call(:state_machine)
        namespace_only
        
        # Store the handled method name for testing
        @handles_method = :state_machine

        # The generated state machine
        attr_reader :machine

        def process
          # Cross-file storage for state machines
          globals.state_machines ||= Hash.new { |h, k| h[k] = {} }
          namespace['state_machines'] ||= {}

          # Create new machine
          klass = inherited_machine ? Class.new(inherited_machine.owner_class) : Class.new { extend StateMachines::MacroMethods }
          @machine = klass.state_machine(name, options) {}

          # Track the state machine
          globals.state_machines[namespace.name][name] = machine
          namespace['state_machines'][name] = {name: name, description: statement.docstring}

          # Parse the block
          parse_block(statement.last.last, owner: machine)

          # Draw the machine for reference in the template
          file = Tempfile.new(['state_machine', '.png'])
          begin
            if machine.draw(name: File.basename(file.path, '.png'), path: File.dirname(file.path), orientation: 'landscape')
              namespace['state_machines'][name][:image] = file.read
            end
          ensure
            # Clean up tempfile
            file.close
            file.unlink
          end

          # Define auto-generated methods
          define_macro_methods
          define_state_methods
          define_event_methods
        end

        protected
        # Extracts the machine name's
        def name
          @name ||= begin
            ast = statement.parameters.first
            if ast && [:symbol_literal, :string_literal].include?(ast.type)
              extract_node_name(ast)
            else
              :state
            end
          end
        end

        # Extracts the machine options.  Note that this will only extract a
        # subset of the options supported.
        def options
          @options ||= begin
            options = {}
            ast = statement.parameters(false).last

            if !inherited_machine && ast && ![:symbol_literal, :string_literal].include?(ast.type)
              ast.children.each do |assoc|
                # Only extract important options
                key = extract_node_name(assoc[0])
                next unless [:initial, :attribute, :namespace, :action].include?(key)

                value = extract_node_name(assoc[1])
                options[key] = value
              end
            end

            options
          end
        end

        # Gets the machine that was inherited from a superclass.  This also
        # ensures each ancestor has been loaded prior to looking up their definitions.
        def inherited_machine
          @inherited_machine ||= begin
            namespace.inheritance_tree.each do |ancestor|
              begin
                ensure_loaded!(ancestor)
              rescue YARD::Handlers::NamespaceMissingError
                # Ignore: just means that we can't access an ancestor
              end
            end

            # Find the first ancestor that has the machine
            loaded_superclasses.find do |superclass|
              if superclass != namespace
                machine = globals.state_machines[superclass.name][name]
                break machine if machine
              end
            end
          end
        end

        # Gets members of this class's superclasses have already been loaded
        # by YARD
        def loaded_superclasses
          namespace.inheritance_tree.select { |ancestor| ancestor.is_a?(YARD::CodeObjects::ClassObject) }
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
          @integration ||= Integrations.match_ancestors(namespace.inheritance_tree(true).map { |ancestor| ancestor.path })
        end

        # Gets the class type being used to define states.  Default is "Symbol".
        def state_type
          @state_type ||= machine.states.any? ? machine.states.map { |state| state.name }.compact.first.class.to_s : 'Symbol'
        end

        # Gets the class type being used to define events.  Default is "Symbol".
        def event_type
          @event_type ||= machine.events.any? ? machine.events.first.name.class.to_s : 'Symbol'
        end

        # Defines auto-generated macro methods for the given machine
        def define_macro_methods
          # Don't exit early for inherited machine since we need to register instance methods
          # even for inherited machines
          
          # Human state name lookup (class method)
          register(m = YARD::CodeObjects::MethodObject.new(namespace, "human_#{machine.attribute(:name)}", :class))
          m.docstring = [
              'Gets the humanized name for the given state.',
              "@param [#{state_type}] state The state to look up",
              '@return [String] The human state name'
          ]
          m.parameters = ['state']

          # Human event name lookup (class method)
          register(m = YARD::CodeObjects::MethodObject.new(namespace, "human_#{machine.attribute(:event_name)}", :class))
          m.docstring = [
              'Gets the humanized name for the given event.',
              "@param [#{event_type}] event The event to look up",
              '@return [String] The human event name'
          ]
          m.parameters = ['event']
          
          # Skip the rest if this is an inherited machine
          return if inherited_machine

          # Only register attributes when the accessor isn't explicitly defined
          # by the class / superclass *and* isn't defined by inference from the
          # ORM being used
          unless integration || instance_attributes.include?(machine.attribute.to_sym)
            attribute = machine.attribute
            namespace.attributes[:instance][attribute] = {}

            # Machine attribute getter
            register(m = YARD::CodeObjects::MethodObject.new(namespace, attribute))
            namespace.attributes[:instance][attribute][:read] = m
            m.docstring = [
                'Gets the current attribute value for the machine',
                '@return The attribute value'
            ]

            # Machine attribute setter
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{attribute}="))
            namespace.attributes[:instance][attribute][:write] = m
            m.docstring = [
                'Sets the current value for the machine',
                "@param new_#{attribute} The new value to set"
            ]
            m.parameters = ["new_#{attribute}"]
          end

          if integration && integration.defaults[:action] && !options.include?(:action) || options[:action]
            attribute = "#{machine.name}_event"
            namespace.attributes[:instance][attribute] = {}

            # Machine event attribute getter
            register(m = YARD::CodeObjects::MethodObject.new(namespace, attribute))
            namespace.attributes[:instance][attribute][:read] = m
            m.docstring = [
                'Gets the current event attribute value for the machine',
                '@return The event attribute value'
            ]

            # Machine event attribute setter
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{attribute}="))
            namespace.attributes[:instance][attribute][:write] = m
            m.docstring = [
                'Sets the current value for the machine',
                "@param new_#{attribute} The new value to set"
            ]
            m.parameters = ["new_#{attribute}"]
          end

          # These instance methods are always defined, even for inherited machines
          
          # Presence query
          register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{machine.name}?"))
          m.docstring = [
              'Checks the given state name against the current state.',
              "@param [#{state_type}] state_name The name of the state to check",
              '@return [Boolean] True if they are the same state, otherwise false',
              '@raise [IndexError] If the state name is invalid'
          ]
          m.parameters = ['state_name']

          # Internal state name
          register(m = YARD::CodeObjects::MethodObject.new(namespace, machine.attribute(:name)))
          m.docstring = [
              'Gets the internal name of the state for the current value.',
              "@return [#{state_type}] The internal name of the state"
          ]

          # Human state name instance method - this is always defined regardless of inheritance
          # Ensure the name is correct - we explicitly check the attribute name to make sure it's generated correctly
          human_method_name = "human_#{machine.attribute(:name)}"
          register(m = YARD::CodeObjects::MethodObject.new(namespace, human_method_name))
          m.docstring = [
              'Gets the human-readable name of the state for the current value.',
              '@return [String] The human-readable state name'
          ]
          
          # Debug output for testing - we want to make sure we're registering the method correctly
          # puts "Registered instance method: #{namespace}##{human_method_name} (#{m})"
          
          # The below methods should only be defined for non-inherited machines
          return if inherited_machine

          # Available events
          register(m = YARD::CodeObjects::MethodObject.new(namespace, machine.attribute(:events)))
          m.docstring = [
              "Gets the list of events that can be fired on the current #{machine.name} (uses the *unqualified* event names)",
              '@param [Hash] requirements The transition requirements to test against',
              "@option requirements [#{state_type}] :from (the current state) One or more initial states",
              "@option requirements [#{state_type}] :to One or more target states",
              "@option requirements [#{event_type}] :on One or more events that fire the transition",
              '@option requirements [Boolean] :guard Whether to guard transitions with conditionals',
              "@return [Array<#{event_type}>] The list of event names"
          ]
          m.parameters = [['requirements', '{}']]

          # Available transitions
          register(m = YARD::CodeObjects::MethodObject.new(namespace, machine.attribute(:transitions)))
          m.docstring = [
              "Gets the list of transitions that can be made for the current #{machine.name}",
              '@param [Hash] requirements The transition requirements to test against',
              "@option requirements [#{state_type}] :from (the current state) One or more initial states",
              "@option requirements [#{state_type}] :to One or more target states",
              "@option requirements [#{event_type}] :on One or more events that fire the transition",
              '@option requirements [Boolean] :guard Whether to guard transitions with conditionals',
              '@return [Array<StateMachines::Transition>] The available transitions'
          ]
          m.parameters = [['requirements', '{}']]

          # Available transition paths
          register(m = YARD::CodeObjects::MethodObject.new(namespace, machine.attribute(:paths)))
          m.docstring = [
              "Gets the list of sequences of transitions that can be run for the current #{machine.name}",
              '@param [Hash] requirements The transition requirements to test against',
              "@option requirements [#{state_type}] :from (the current state) The initial state",
              "@option requirements [#{state_type}] :to The target state",
              '@option requirements [Boolean] :deep Whether to enable deep searches for the target state',
              '@option requirements [Boolean] :guard Whether to guard transitions with conditionals',
              '@return [StateMachines::PathCollection] The collection of paths'
          ]
          m.parameters = [['requirements', '{}']]

          # Generic event fire
          register(m = YARD::CodeObjects::MethodObject.new(namespace, "fire_#{machine.attribute(:event)}"))
          m.docstring = [
              "Fires an arbitrary #{machine.name} event with the given argument list",
              "@param [#{event_type}] event The name of the event to fire",
              '@param args Optional arguments to include in the transition',
              '@return [Boolean] +true+ if the event succeeds, otherwise +false+'
          ]
          m.parameters = ['event', '*args']
        end

        # Defines auto-generated event methods for the given machine
        def define_event_methods
          machine.events.each do |event|
            next if inherited_machine && inherited_machine.events[event.name]

            # Event query
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "can_#{event.qualified_name}?"))
            m.docstring = [
                "Checks whether #{event.name.inspect} can be fired.",
                '@param [Hash] requirements The transition requirements to test against',
                "@option requirements [#{state_type}] :from One or more initial states",
                "@option requirements [#{state_type}] :to One or more target states",
                '@option requirements [Boolean] :guard Whether to guard transitions with conditionals',
                "@return [Boolean] +true+ if #{event.name.inspect} can be fired, otherwise +false+"
            ]
            m.parameters = [['requirements', '{}']]

            # Event transition
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{event.qualified_name}_transition"))
            m.docstring = [
                "Gets the next transition that would be performed if #{event.name.inspect} were to be fired.",
                '@param [Hash] requirements The transition requirements to test against',
                "@option requirements [#{state_type}] :from One or more initial states",
                "@option requirements [#{state_type}] :to One or more target states",
                '@option requirements [Boolean] :guard Whether to guard transitions with conditionals',
                '@return [StateMachines::Transition] The transition that would be performed or +nil+'
            ]
            m.parameters = [['requirements', '{}']]

            # Fire event
            register(m = YARD::CodeObjects::MethodObject.new(namespace, event.qualified_name))
            m.docstring = [
                "Fires the #{event.name.inspect} event.",
                '@param [Array] args Optional arguments to include in transition callbacks',
                '@return [Boolean] +true+ if the transition succeeds, otherwise +false+'
            ]
            m.parameters = ['*args']

            # Fire event (raises exception)
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{event.qualified_name}!"))
            m.docstring = [
                "Fires the #{event.name.inspect} event, raising an exception if it fails.",
                '@param [Array] args Optional arguments to include in transition callbacks',
                '@return [Boolean] +true+ if the transition succeeds',
                '@raise [StateMachines::InvalidTransition] If the transition fails'
            ]
            m.parameters = ['*args']
          end
        end

        # Defines auto-generated state methods for the given machine
        def define_state_methods
          machine.states.each do |state|
            next if inherited_machine && inherited_machine.states[state.name] || !state.name

            # State query
            register(m = YARD::CodeObjects::MethodObject.new(namespace, "#{state.qualified_name}?"))
            m.docstring = [
                "Checks whether #{state.name.inspect} is the current state.",
                '@return [Boolean] +true+ if this is the current state, otherwise +false+'
            ]
          end
        end
      end
    end
  end
end
