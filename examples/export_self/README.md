# Exporting a module as a proc

This example demonstrates an interesting technique for injecting dependencies
using procs or otherwise performing side effects using procs. In the present
case we implement a very simple [side-effects system](app.rb) that takes effect
handlers as procs. The [`log`](log.rb) module exports a proc as a default value.
The proc, when run, returns the module, allowing access to its methods and
constants. In essence, importing the `log` module returns a closure that returns
the module.

For more information on using side-effects or algebraic effects in Ruby, see the
[Affect](https://github.com/digital-fabric/affect) gem.