* Forwarder module

The forward or 
[delegate pattern](http://radar.oreilly.com/2014/02/delegation-patterns-in-ruby.html)
forwards method calls to an arbitrary receiver object. In this example, the
[imported module](forwarder.rb) exports a single method, `#receiver=`, used to 
set the receiver. All method calls to the module are intercepted using 
`#method_missing` and then forwarded / delegated to the receiver.

The [application](app.rb) demonstrates forwarding calls to the `Time` class 
using the forwarder module.