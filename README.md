# State Machines YARD plugin

State machines YARD plugin for automated documentation

## Installation

Add this line to your application's Gemfile:

    gem 'state_machines-yard', group: :development

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install state_machines-yard

## Events

Whatever the renderer, each class's documentation lists its machines' events, and
each event's method (`ignite`, `ignite!`) describes the transitions it performs: from
each state the first branch that matches, its guards and the callbacks that run on it in
the order the core runs them (an around where it enters; a transition's own
`before:`/`around:`/`after:` closest to the state change, after the machine's befores and
before its afters), and the `after_failure` callbacks:

    * parked -> idling [if engine_ok? && if_any_state (gate=open, alarm=off)] / before check_mirrors, after log_start (if logging?)
    * parked -> stalled / before check_mirrors

    On failure: alert

The text is read through [state_machines-diagram](https://github.com/state-machines/state_machines-diagram),
so it labels guards and callbacks exactly as the diagrams do.

## Diagrams

Diagrams are an optional extra. Set `STATE_MACHINES_RENDERER` to draw each documented machine:

* `graphviz` embeds a PNG drawn by [state_machines-graphviz](https://github.com/state-machines/state_machines-graphviz)
  (needs the `dot` binary)
* `mermaid` embeds a Mermaid diagram drawn by [state_machines-mermaid](https://github.com/state-machines/state_machines-mermaid)
* `none` (the default) draws nothing

The plugin reads the state machine DSL without running it. Transitions carry the
guards the core runs: `if:`/`unless:` conditions (each one of an Array, a String
as the code it is, a lambda or other code by its source) and state guards
(`if_state`, `if_all_states`, `if_any_state`, `unless_state`, `unless_all_states`,
`unless_any_state`), each group with its requirements. A requirement or state guard
only known when the code runs (a constant, a method call) cannot be documented
faithfully, so that transition is left out with a warning; an initial state
written as code documents no state as initial.

Transition callbacks (`before_transition`, `after_transition`, `around_transition`,
`after_failure`) are read the same way: their methods (positional, `do:`, a block),
the transitions they run on (`from`/`to`/`on`, their `except_` forms, `a => b`
pairs) and their own conditions. A transition's own callbacks
(`transition parked: :idling, before: :prime, after: -> { log }`) are read as methods the
same way, in an event or a state's block. Diagrams show them as the renderers label them:
a Symbol by name, String code as written, a block or lambda as `lambda@file:line`,
a conditional callback with its conditions. A diagram a renderer fails to draw is
left out with a warning; the rest of the class's documentation stands.

## Testing

A comprehensive test suite is included for the gem. To run all tests:

```
rake test
```

## Contributing

1. Fork it ( https://github.com/state-machines/state_machines-yard/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
