# Module based on lambdas

Lambdas in Ruby (or procs if you will, the difference is not important in the 
present context) are powerful abstractions that make it possible to write 
functional Ruby code in general and higher-order functions in particular.

The present example demonstrates a module written using nothing but lambdas, 
where its [entry point](calc.rb#5) itself is a lambda. The [application](app.rb) 
in turn uses the imported object as a callable.

This example also demonstrates the power of `export_default`, which can be used
to hide a ton of complexity behind *any* Ruby object.
