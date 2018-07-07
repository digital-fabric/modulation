# modul

modul provides an alternative way to organize your code. Instead of littering the global namespace with classes and modules, you can organize your code using enclosed, well-separated modules. This way of organizing code might look more natural for code bases leaning towards functional programming.

> Loading modules with modul resembles in some ways the functionality provided
> Python, node.js, Go and other programming languages.

Here's a simple example:

*math.rb*
```ruby
# math.rb
def fib(n)
  (0..1).include?(n) ? n : (fib(n - 1) + fib(n - 2))
end
```
*app.rb*
```ruby
require 'modul'
math = import('./math')
puts math.fib(10)
```

## Organizing a Ruby code base with modul

### Modules

Each module's code is loaded into an object that provides access to the 
module's classes, constants and methods. Therefore, wherever a source file
uses a module, it explicitely refers to it using the global `import` method, 
and usually saves the module to a variable or a constant for later use:

```ruby
require 'modul'
Models = import('./models')
...

user = Models::User.new(...)

...
```

> **Note about paths**: module paths are always relative to the file calling the
> `import` method.

A module may expose a set of methods without enclosing them in a module or a 
class, for example when writing in a functional style:

*seq.rb*
```ruby
def fib(n)
  (0..1).include?(n) ? n : (fib(n - 1) + fib(n - 2))
end

def luc(n)
  (0..1).include?(n) ? (2 - n) : (luc(n - 1) + luc(n - 2))
end
```
*app.rb*
```ruby
require 'modul'
seq = import('./seq')
puts seq.fib(10)
```

### Default exports

A module may wish to expose just a single class or constant, in which case it can use `default_export`:

```ruby
# user.rb
class User
  ...
end

default_export User

# app.rb
require 'modul'
User = import('./user')
User.new(...)
```

### Private methods

Any methods that do not need to be exposed can be marked as private just like
in class definitions:

*greeter.rb*
```ruby
def greet!(name)
  puts greeting(name)
end

private
def greeting(name)
  "Hello #{name}!"
end
```
*app.rb*
```ruby
require 'modul'
greeter = import('./greeter')
greeter.greet!('world')
```

### Namespaces

Modules can be further organised by using the concept of namespaces. Namespaces
behave just like modules, but multiple namespaces can exist in a single file:

*auth.rb*
```ruby
namespace :sessions do
  def verify_session(session_id)
    ...
  end

  ...
end

namespace :users do
  def verify_user(name, password)
    ...
  end

  ...
end
```
*app.rb*
```ruby
require 'modul'
auth = import('./auth')
...
auth.sessions.verify_session(sid)
auth.users.verify_user(name, password)
```

## Design principles

- Minimal code size
- Minimal alteration of base classes
- Minimal global classes and 

## What benefits does it offer?

- Explicit code dependencies (each module needs to be explicitly imported in each place it is used).
- Better code separation (code can be split into smaller, well defined parts)
- Less boilerplate (no more deeply nested class namespaces, singleton classes or `class << self`)
- Suitable for functional-style programming.

## What are the limitations of using modul?

- Doesn't play well with gems (i.e., currently there's no easy way to import a 'gem')
- Doesn't play well with `require`
- Doesn't play well with code-analysis tools like SolarGraph
