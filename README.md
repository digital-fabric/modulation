# Modul - better dependencies for Ruby

Modul provides an alternative way to organize Ruby code. Instead of littering the global namespace with classes and modules, Mrodul lets you use explicit imports and exports in order to better control dependencies in your codebase.

With Modul, you always know where a module comes from, and you have full control over which parts of a module's code you wish to expose to the outside world. With Modul, you can more easily write in a functional style with a minimum of boilerplate code.

## Rationale

Using Ruby's `require` to split your code poses a number of problems:

- Once a file is `require`d, any class, module or constant in it is available to any other file in your code. All classes, modules and constants are defined globally, in a single namespace, which makes it easy to have class name collisions.
- Since a `require` can appear in any file in your code, it's easy to lose track of where a certain file was required and where it is used.
- To avoid class name collisions, classes need to be nested under a single hierarchical tree, sometime reaching 4 levels or more, i.e. `ActiveSupport::Messages::Rotator::Encryptor`.
- There's no easy way to control the visibility of specific classes, modules and constants. Everything is wide-open.
- Writing reusable functional code requires wrapping it in modules using `class << self`, `def self.foo ...` or `include Singleton`.

Personally, I have found that managing dependencies with `require` over a large codebase is... not as elegant or painfree as I would expect from a first-class development environment.

So I came up with Modul, a small gem that takes the opposite approach to organizing code using multiple files: any defined classes, modules or constants are hidden unless explicitly exported, and the global namespace remains clutter-free.

Here's a simple example:

*math.rb*
```ruby
# math.rb
export :fib

def fib(n)
  (0..1).include?(n) ? n : (fib(n - 1) + fib(n - 2))
end
```
*app.rb*
```ruby
require 'modul'
Math = import('./math')
puts Math.fib(10)
```

## Organizing Ruby code base with Modul

### Importing modules

With Modul, each imported file is loaded into a separate namespace (technically, a Ruby `Module`) that provides access to any methods, classes, modules and constants that were explicitly shared using calls to `export`.

Therefore, whenever a source file uses a module, it explicitely refers to it using the global `import` method, and usually saves the module to a constant or a local variable for later use:

```ruby
require 'modul'
Models = import('./models')
...

user = Models::User.new(...)

...
```

> **Note about paths**: module paths are always relative to the file calling the
> `import` method.

### Exporting functionality

To allow other files to access a module's functionality, use `export`:

```ruby
export :User

class User
...
end
```

A module may also expose a set of methods without enclosing them in a module or a 
class, for example when writing in a functional style:

*seq.rb*
```ruby
export :fib, :luc

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
Seq = import('./seq')
puts Seq.fib(10)
```

### Default exports

A module may wish to expose just a single class or constant, in which case it can use `export_default`:

*user.rb*
```ruby
export_default :User

class User
  ...
end
```

*app.rb*
```ruby
require 'modul'
User = import('./user')
User.new(...)
```

### Namespaces

Modules can be further organised by using the concept of namespaces. Namespaces
behave just like modules, but multiple namespaces can exist in a single file:

*auth.rb*
```ruby
export :Sessions, :Users

namespace :Sessions do
  export :verify_session

  def verify_session(session_id)
    ...
end

namespace :Users do
  export :verify_user

  def verify_user(name, password)
    ...
end
```
*app.rb*
```ruby
require 'modul'
Auth = import('./auth')
...
Auth::Sessions.verify_session(sid)
Auth::Users.verify_user(name, password)
```

> **Note about namespaces**: defining a namespace will prevent access to any methods or classes contained in that namespace, even from the same file, unless they are *explicitly* exported.

## Design principles

- Minimal code size
- Minimal alteration of base classes
- Play nice with core Ruby and Ruby gems

## What are the limitations to using Modul?

- Will probably cause a mess if used to import gems.
- Doesn't play well with `Marshall`.
- Doesn't play well with code-analysis tools.
