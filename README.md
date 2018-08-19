# Modulation - better dependency management for Ruby

[INSTALL](#installing-modulation) |
[GUIDE](#organizing-your-code-with-modulation) |
[EXAMPLES](https://github.com/ciconia/modulation/tree/master/examples) |
[DOCS](https://www.rubydoc.info/gems/modulation/)

Modulation provides an better way to organize Ruby code. Modulation lets you 
explicitly import and export declarations in order to better control 
dependencies in your codebase. Modulation helps you refrain from littering
the global namespace with a myriad modules, or declaring complex nested
class hierarchies.

Using Modulation, you will always be able to tell know where a piece of code 
comes from, and you'll have full control over which parts of a module's code 
you wish to expose to the outside world. Modulation also helps you write Ruby 
code in a functional style, with a minimum of boilerplate code.

## Features

- Provides complete isolation of each module for better control of dependencies.
- Can reload modules at runtime without breaking your code in wierd ways.
- Supports circular dependencies.
- Enforces explicit exporting and importing of methods, classes, modules and 
  constants.
- Allows default exports for modules exporting a single class or value.
- Supports nested namespaces with explicit exports.
- Can be used to write gems.

## Rationale

Splitting your Ruby code into multiple files loaded using `require` poses a 
number of problems:

- Once a file is `require`d, any class, module or constant in it is available 
  to any other file in your codebase. All "globals" (classes, modules, 
  constants) are loaded, well, globally, in a single namespace. Namespace 
  collisions are easy in Ruby.
- Since a `require` can appear in any file in your code, it's easy to lose
  track of where a certain file was required and where it is used.
- To avoid class name ocnflicts, classes need to be nested under a single 
  hierarchical tree, sometime reaching 4 levels or more, i.e. 
  `ActiveSupport::Messages::Rotator::Encryptor`.
- There's no easy way to control the visibility of specific so-called globals. 
  Everything is wide-open.
- Writing reusable functional code requires wrapping it in modules using 
  `class << self`, `def self.foo ...` or `include Singleton`.

Personally, I have found that managing dependencies with `require` over in 
large codebases is... not as elegant or painfree as I would expect from a 
first-class development environment.

So I came up with Modulation, a small gem that takes a different approach to 
organizing Ruby code: any so-called global declarations are hidden unless 
explicitly exported, and the global namespace remains clutter-free. All 
dependencies between source files are explicit, and are easily grokked.

Here's a simple example:

*math.rb*
```ruby
export :fib

def fib(n)
  (0..1).include?(n) ? n : (fib(n - 1) + fib(n - 2))
end
```
*app.rb*
```ruby
require 'modulation'
MyMath = import('./math')
puts MyMath.fib(10)
```

## Installing Modulation

You can install the Modulation as a gem, or add it in your `Gemfile`:

```bash
$ gem install modulation
```

## Organizing your code with Modulation

Modulation builds on the idea of a Ruby module as a
["collection of methods and constants"](https://ruby-doc.org/core-2.5.1/Module.html).
Using modulation, any Ruby source file can be a module. Modules usually export
method and constant declarations (usually an API for a specific, well-defined 
functionality) to be shared with other modules. Modules can also import 
declarations from other modules.

Each module is evaluated in the context of a newly-created `Module` instance, 
with some additional methods that make it possible to identify the module's 
source location and reload it.

### Exporting declarations

Any class, module or constant be exported using `export`:

```ruby
export :User, :Session

class User
...
end

class Session
...
end
```

A module may also expose a set of methods without using `class << self`, for 
example when writing in a functional style:

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
require 'modulation'
Seq = import('./seq')
puts Seq.fib(10)
```

### Importing declarations

Declarations from another module can be imported using `import`:

```ruby
require 'modulation'
Models = import('./models')
...

user = Models::User.new(...)

...
```

Alternatively, a module interested in a single declaration from another module 
can use the following technique:

```ruby
require 'modulation'
User = import('./models')::User
...

user = User.new(...)
```

> **Note about paths**: module paths are always relative to the file
> calling the `import` method, just like `require_relative`.

### Default exports

A module may wish to expose just a single class or constant, in which case it 
can use `export_default`:

*user.rb*
```ruby
export_default :User

class User
  ...
end
```

*app.rb*
```ruby
require 'modulation'
User = import('./user')
User.new(...)
```

The default exported value can also be defined directly thus:

*config.rb* 
```ruby
export_default(
  host: 'localhost',
  port: 1234,
  ...
)
```

*app.rb*
```ruby
config = import('./config')
db.connect(config[:host], config[:port])
```

### Further organising module functionality into nested namespaces

Code inside modules can be further organised by separating it into nested 
namespaces. The `export` method can be used to turn a normal nested module
into a self-contained singleton-like object and prevent access to internal
implementation details:

*net.rb*
```ruby
export :Async, :TCPServer

module Async
  export :await

  def await
    Fiber.new do
      yield Fiber.current
      Fiber.yield
    end
  end
end

class TCPServer
  ...
  def read
    Async.await do |fiber|
      on(:read) {|data| fiber.resume data}
    end
  end
end
```

> Note: when `export` is called inside a `module` declaration, Modulation calls
> `extend self` implicitly, just like it does for the top-level loaded module.
> That way there's no need to declare methods using the `def self.xxx` syntax,
> and the module can still be used to extend arbitrary classes or objects.

### Importing methods into classes and modules

Modulation provides the `extend_from` and `include_from` methods to include
imported methods in classes and modules:

```ruby
module Sequences
  extend_from('./seq.rb')
end

Sequences.fib(5)

# extend integers
class Integer
  include_from('./seq.rb')

  def seq(kind)
    send(kind, self)
  end
end

5.seq(:fib)
```

### Accessing a module from nested namespaces within itself

The special constant `MODULE` allows you to access the containing module from
nested namespaces. This lets you call methods defined in the module's root
namespace, or otherwise introspect the module.

```ruby
export :await, :MyServer

# Await a promise-like callable
def await
  calling_fiber = Fiber.current
  p = ->(v = nil) {calling_fiber.resume v}
  yield p
  Fiber.yield
end

class MyServer < SuperSecretTCPServer
  def async_read
    MODULE.await {|p| on_read {|data| p.(data)}}
  end
end
```

### Accessing the global namespace

If you need to access the global namespace inside a module just prefix the 
class name with double colons:

```ruby
class ::GlobalClass
  ...
end

::ENV = { ... }

what = ::MEANING_OF_LIFE
```

### Reloading modules

Modules can be easily reloaded in order to implement hot code reloading:

```ruby
SQL = import('./sql')
...
SQL.__reload!
```

Another way to reload modules is using `Modulation.reload`, which accepts a
module or a filename:

```ruby
require 'filewatcher'

FileWatcher.new(['lib']).watch do |fn, event|
  if(event == :changed)
    Modulation.reload(fn)
  end
end
```

Reloading of default exports is also possible. Modulation will extend the 
exported value with a `#__reload!` method. The value will need to be
reassigned:

```ruby
settings = import('settings')
...
settings = settings.__reload!
```

## Writing gems using Modulation

Modulation can be used to write gems, providing fine-grained control over your
gem's public APIs and letting you hide any implementation details. In order to
allow loading a gem using either `require` or `import`, code your gem's main
file normally, but add  `require 'modulation/gem'` at the top, and export your
gem's main namespace as a default export, e.g.:

```ruby
require 'modulation/gem'

export_default :MyGem

module MyGem
  ...
  MyClass = import('my_gem/my_class')
  ...
end
```

## Importing gems using Modulation

Gems written using modulation can also be loaded using `import`. If modulation
does not find the module specified by the given relative path, it will attempt
to load a gem by the same name.

> **Note**: using `import` to load a gem is very much *experimental*, and might
> introduce problems not encountered when loading with `require` such as 
> shadowing of global namespaces, or any other bizarre and unexpected
> behaviors. Actually, there's not much point in using it to load a gem which
> does not use Modulation. When loading gems using import, Modulation will
> raise an exception if no symbols were exported by the gem.

## Coding style recommendations

* Import modules into constants, not into variables:

  ```ruby
  Settings = import('./settings')
  ```

* Place your exports at the top of your module:

  ```ruby
  export :foo, :bar, :baz

  ...
  ```

* Place your imports at the top of your module:

  ```ruby
  Foo = import('./foo')
  Bar = import('./bar')
  Baz = import('./baz')
  ...
  ```

## Known limitations and problems

- Modulation is (probably) not production-ready.
- Modulation is not thread-safe.
- Modulation probably doesn't play well with `Marshal`.
- Modulation probably doesn't play well with code-analysis tools.
- Modulation probably doesn't play well with rdoc/yard.