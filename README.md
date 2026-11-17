# State Machines YARD plugin

State machines YARD plugin for automated documentation

## Installation

Add this line to your application's Gemfile:

    gem 'state_machines-yard', group: :development

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install state_machines-yard

## Diagrams

Set `STATE_MACHINES_RENDERER` to draw each documented machine:

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
