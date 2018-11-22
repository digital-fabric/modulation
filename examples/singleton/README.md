# Singleton pattern using Modulation

One of the most common programming patterns in Ruby is the singleton pattern,
which is especially useful when writing in a more functional style. Modulation
makes it easier to write singletons by treating source-file as *singleton 
modules* by default. Thus, any method defined in such a module is a *singleton*
method. This reduces the boilerplate usually involved in writing Ruby singelton
to the bare minimum.

In the present example, the [imported module](lancelot.rb) is a singleton 
implementing the interface expected by the [application](bridge_keeper.rb).