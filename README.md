# Modulation - Explicit Dependency Management for Ruby

> Modulation | mɒdjʊˈleɪʃ(ə)n | *Music* -  a change from one key to another in a
> piece of music.

[INSTALL](#installing-modulation) |
[GUIDE](#organizing-your-code-with-modulation) |
[API](#api-reference) |
[EXAMPLES](examples) |
[RDOC](https://www.rubydoc.info/gems/modulation/)

Modulation provides an alternative way of organizing your Ruby code. Modulation
lets you explicitly import and export declarations in order to better control 
dependencies in your codebase. Modulation helps you refrain from littering
the global namespace with a myriad modules, or complex multi-level nested
module hierarchies.

Using Modulation, you will always be able to tell where a class or module comes
from, and you'll have full control over which parts of a module's code you wish
to expose to the outside world. Modulation can also help you write Ruby code in
a functional style, minimizing boilerplate code.

> Note: Modulation is not a replacement for RubyGems. Rather, Modulation is 
> intended for managing dependencies between source files *inside* your Ruby
> applications. Though it does support loading gems that were written using 
> Modulation, it is not intended as a comprehensive solution for using 
> third-party libraries.

## Features

- Complete isolation of each module.
- Explicit exporting and importing of methods and constants.
- Support for circular dependencies.
- Support for [default exports](#default-exports) for modules exporting a single
  class or value.
- [Lazy Loading](#lazy-loading) improves start up time and memory consumption.
- [Hot module reloading](#reloading-modules)
- [Mocking of dependencies](#mocking-dependencies) for testing purposes.
- Can be used to [write gems](#writing-gems-using-modulation).
- [Dependency introspection](#dependency-introspection).
- Support for [creating modules programmatically](#programmatic-module-creation).
- Easier [unit-testing](#unit-testing-modules) of private methods and
  constants.
- Pack entire applications [into a single
  file](#packing-applications-with-modulation).

## Rationale

You're probably asking yourself "what the ****?" , but when your Ruby app grows
and is split into multiple files loaded using `#require`, you'll soon hit some
issues:

- Once a file is `#require`d, any class, module or constant in it is available
  to any other file in your codebase. All "globals" (classes, modules,
  constants) are loaded, well, globally, in a single namespace. Name conflicts
  are easy in Ruby.
- To avoid class name conflicts, classes need to be nested under a single 
  hierarchical tree, sometime reaching 4 levels or more. Just look at Rails.
- Since a `#require`d class or module can be loaded in any file and then made
  available to all files, it's easy to lose track of where it was loaded, and
  where it is used.
- There's no easy way to hide implementation-specific classes or methods. Yes,
  there's `#private`, `#private_constant` etc, but by default everything is 
  `#public`!
- Extracting functionality is harder when modules are namespaced and
  dependencies are implicit.
- Writing reusable functional code requires wrapping it in modules using 
  `class << self`, `def self.foo ...`, `extend self` or `include Singleton`
  (the pain of implementing singletons in Ruby has been
  [discussed](https://practicingruby.com/articles/ruby-and-the-singleton-pattern-dont-get-along)
  [before](https://ieftimov.com/singleton-pattern).)

> There's a [recent discussion](https://bugs.ruby-lang.org/issues/14982) on the
> Ruby bug tracker regarding possible solutions to the problem of top-level
> name collision. Hopefully, the present gem could contribute to an eventual
> "official" API.

Personally, I have found that managing dependencies with `#require` in large
codebases is... not as elegant or painfree as I would expect from a 
first-class development environment. I also wanted to have a better solution
for writing in a functional style.

So I came up with Modulation, a small gem that takes a different approach to
organizing Ruby code: any so-called global declarations are hidden unless
explicitly exported, and the global namespace remains clutter-free. All
dependencies between source files are explicit, visible, and easy to understand.

## Installing Modulation

You can install the Modulation using `gem install`, or add it to your `Gemfile`:

```ruby
gem 'modulation'
```

## Organizing your code with Modulation

Modulation builds on the idea of a Ruby `Module` as a
["collection of methods and constants"](https://ruby-doc.org/core-2.5.1/Module.html).
Using modulation, each Ruby source file becomes a module. Modules usually
export method and constant declarations (usually an API for a specific, 
well-defined functionality) to be shared with other modules. Modules can also
import declarations from other modules. Anything not exported remains hidden
inside the module and normally cannot be accessed from the outside.

Each source file is evaluated in the context of a newly-created `Module` 
instance, with some additional methods for introspection and miscellaneous
operations such as [hot reloading](#reloading-modules).

Modulation provides an alternative APIs for loading modules. Instead of using
`require` and `require_relative`, you use `import`, `import_map` and other APIs.

### Exporting declarations

Any class, module or constant be exported using `#export`:

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

Another way to export methods and constants is by passing a hash to `#export`:

*module.rb*
```ruby
export(
  foo: :bar,
  baz: -> { 'hello' },
  MY_CONST: 42
)

def bar
  :baz
end
```

*app.rb*
```ruby
m = import('./module')
m.foo #=> :baz
m.baz #=> 'hello'
m::MY_CONST #=> 42
```

Any capitalized key will be interpreted as a const, otherwise it will be defined
as a method. If the value is a symbol, Modulation will look for the
corresponding method or const definition and will treat the key as an alias.

The `export` method can be called multiple times. Its behavior is additive:

```ruby
# this:
export :foo, :bar

# is the same as this:
export :foo
export :bar
```

### Importing declarations

Declarations from another module can be imported using `#import`:

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

### Using tags to designate common subdirectories

Normally, module paths are always relative to the file calling the `#import`
method, just like `#require_relative`. This can become a problem once you start
moving your source files around. In addition, in applications where your source
files are arranged in multiple directories, it can quickly become tedious to do
stuff like `Post = import('../models/post')`.

Modulation provides an alternative to relative paths in the form of tagged
sources. A tagged source is simply a path associated with a label. For example,
an application may tag `lib/models` simply as `@models`. Once tags are defined,
they can be used when importing files, e.g. `import('@models/post')`.

### Importing all source files in a directory

To load all source files in a directory you can use `#import_all`:

```ruby
import_all('./ext') # will load ./ext/kernel.rb, ./ext/socket.rb etc 
```

Groups of modules providing a uniform interface can also be loaded using
`#import_map`:

```ruby
API = import_map('./math_api') #=> hash mapping filenames to modules
API.keys #=> ['add', 'mul', 'sub', 'div']
API['add'].(2, 2) #=> 4
```

The `#import_map` takes an optional block to transform hash keys:

```ruby
API = import_map('./math_api') { |name, mod| name.to_sym }
API.keys #=> [:add, :mul, :sub, :div]
API[:add].(2, 2) #=> 4
```

### Importing methods into classes and objects

Modulation provides the `#extend_from` and `#include_from` methods to include
imported methods in classes and objects:

```ruby
module Sequences
  extend_from('./seq.rb')
end

Sequences.fib(5)

# extend integers
require 'modulation'
class Integer
  include_from('./seq.rb')

  def seq(kind)
    send(kind, self)
  end
end

5.seq(:fib)
```

The `#include_from` method accepts an optional list of symbols to import:

```ruby
class Integer
  include_from './seq.rb', :fib
end

5.fib
```

### Default exports

A module may wish to expose just a single class or constant, in which case it 
can use `#export_default`:

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
require 'modulation'
config = import('./config')
db.connect(config[:host], config[:port])
```

### Accessing a module's root namespace from nested modules within itself

The special constant `MODULE` allows you to access the containing module from
nested modules or classes. This lets you call methods defined in the module's
root namespace, or otherwise introspect the module:

```ruby
export :AsyncServer

# Await a promise-like callable
def await
  calling_fiber = Fiber.current
  p = ->(v = nil) {calling_fiber.resume v}
  yield p
  Fiber.yield
end

class AsyncServer < SomeTCPServer
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

what_is = ::THE_MEANING_OF_LIFE
```

### Programmatic module creation

In addition to loading modules from files, modules can be created dynamically at
runtime using `Modulation.create`. You can create modules by supplying a hash
prototype, a string or a block:

```ruby
# Using a hash prototype
m = Modulation.create(
  add: -> x, y { x + y },
  mul: -> x, y { x * y }
)
m.add(2, 3)
m.mul(2, 3)

# Using a string
m = Modulation.create <<~RUBY
export :foo

def foo
  :bar
end
RUBY

m.foo

# Using a block
m = Modulation.create do { |mod|
  export :foo

  def foo
    :bar
  end

  class mod::BAZ
    ...
  end
}

m.foo
```

The creation of a objects using a hash prototype is also available as a separate
gem called [eg](https://github.com/digital-fabric/eg/).

### Unit testing modules

Methods and constants that are not exported can be tested using the `#__expose!`
method. Thus you can keep implementation details hidden, while being able to 
easily test them:

*parser.rb*
```ruby
export :parse

def parse(inp)
  split(inp).map(&:to_sym)
end

# private method
def split(inp)
  inp.split(',').map(&:strip)
end
```

*test_seq.rb*
```ruby
require 'modulation'
require 'minitest/autorun'

Parser = import('../lib/parser').__expose!

class FibTest < Minitest::Test
  def test_that_split_trims_split_parts
    assert_equal(%w[abc def ghi], Parser.split(' abc ,def , ghi  '))
  end
end
```

### Mocking dependencies

Modules loaded by Modulation can be easily mocked when running tests or specs,
using `Modulation.mock`:

```ruby
require 'minitest/autorun'
require 'modulation'

module MockStorage
  extend self

  def get_user(user_id)
    {
      user_id: user_id,
      name: 'John Doe',
      email: 'johndoe@gmail.com'
    }
  end
end

class UserControllerTest < Minitest::Test
  def test_user_storage
    Modulation.mock('../lib/storage', MockStorage) do
      controller = UserController.new
      ...
    end
  end
end
```

### Lazy Loading

Modulation allows the use of lazy-loaded modules - loading of modules only once
they're needed by the application, in similar fashion to `Module#auto_load`. To
lazy load modules use the `#auto_import` method, which takes a constant name and
a path:

```ruby
export :foo

auto_import :BAR, './bar'

def foo
  # the bar module will only be loaded once this method is called
  MODULE::BAR
end
```

> Lazy-loaded constants must always be qualified. When referring to a
> lazy-loaded constant from the module's top namespace, use the `MODULE`
> namespace, as shown above.

The `#auto_import` method can also take a hash mapping constant names to paths.
This is especially useful when multiple concerns are grouped under a single
namespace:

```ruby
export_default :SuperNet

module SuperNet
  auto_import(
    HTTP1:      './http1',
    HTTP2:      './http2',
    WebSockets: './websockets'
  )
end

SuperNet::HTTP1 #=> loads the http1 module
```

### Reloading modules

Modules can be reloaded at run-time for easy hot code reloading:

```ruby
require 'modulation'
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

> When a module is reloaded, its entire content - constants and methods - will
> be replaced. That means that any code using that module could continue to use
> it without even being aware it was reloaded, providing its API has not
> changed.

Reloading of modules with default exports is also possible. Modulation will  
extend the exported value with a `#__reload!` method. The value will need to be
reassigned:

```ruby
require 'modulation'
settings = import('settings')
...
settings = settings.__reload!
```

### Retaining state between reloads

Before a module is reloaded, all of its methods and constants are removed. In
some cases, a module might need to retain state across reloads. You can do this
by simply using instance variables:

```ruby
export :value, :inc

@counter ||= 0

def value
  @counter
end

def incr
  @counter += 1
end
```

Care must be taken not to reassign values outside of methods, as this will
overwrite any value retained in the instance variable. To assign initial values,
use the `||=` operator as in the example above. See also the
[reload example](examples/reload).

## Dependency introspection

Modulation allows runtime introspection of dependencies between modules. You can
interrogate a module's dependencies (i.e. the modules it imports) by calling
`#__depedencies`:

*m1.rb*
```ruby
import ('./m2')
```

*app.rb*
```ruby
m1 = import('./m1')
m1.__depedencies #=> [<Module m2>]
```

You can also iterate over a module's entire dependency tree by using
`#__traverse_dependencies`:

```ruby
m1 = import('./m1')
m1.__traverse_dependencies { |mod| ... }
```

To introspect reverse dependencies (modules *using* a particular module), use
`#__dependent_modules`:

```ruby
m1 = import('./m1')
m1.__depedencies #=> [<Module m2>]
m1.__dependencies.first.__dependent_modules #=> [<Module m1>]
```

## Running Modulation-based applications

Modulation provides a binary script for running Modulation-based applications.
`mdl` is a wrapper around Ruby that loads your application's main file as a
module, and then runs your application's entry point method. Let's look at a
sample application:

*app.rb*
```ruby
def greet(name)
  puts "Hello, #{name}!"
end

def main
  print "Enter your name: "
  name = gets
  greet(name)
end
```

To run this application, execute `mdl app.rb`, or `mdl run app.rb`. `mdl` will
automatically require the `modulation` gem and call the application's entry
point, `#main`.

## Packing applications with Modulation

> *Note*: application packing is at the present time an experimental feature.
> There might be security concerns for packaging your app, such as leaking
> filenames from the developer's machine.

Modulation can also be used to package your entire application into a single
portable file that can be copied to another machine and run as is. To package
your app, use `mdl pack`. This command will perform a dynamic analysis of all
the app's dependencies and will put them together into a single Ruby file.

For more information have a look at the [app](examples/app) example.

## Writing gems using Modulation

Modulation can be used to write gems, providing fine-grained control over your
gem's public APIs and letting you hide any implementation details. In order to
allow loading a gem using either `#require` or `#import`, code your gem's main
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

Gems written using modulation can also be loaded using `#import`. If modulation
does not find the module specified by the given relative path, it will attempt
to load a gem by the same name. It is also possible to load specific files
inside modules by specifying a sub-path:

```ruby
require 'modulation'
MyFeature = import 'my_gem/my_feature'
```

> **Note**: Since there's not much of a point in `#import`ing gems that do not
> use Modulation to export symbols, Modulation will refuse to import any gem
> that does not depend on Modulation.

## Writing modules that patch external classes or modules

It is generally recommended you refrain from causing side effects or patching
external code in your modules. When you do have to patch external classes or
modules (i.e. core, stdlib, or some third-party code) in your module, it's
useful to remember that any module may be eventually reloaded by the application
code. This means that any patching done during the loading of your module must
be [idempotent](https://en.wikipedia.org/wiki/Idempotence), i.e. have the same
effect when performed multiple times. Take for example the following module
code:

```ruby
module ::Kernel
  # aliasing #sleep more than once will break your code
  alias_method :orig_sleep, :sleep

  def sleep(duration)
    STDERR.puts "Going to sleep..."
    orig_sleep(duration)
    STDERR.puts "Woke up!"
  end
end
```

Running the above code more than once would cause an infinite loop when calling
`Kernel#sleep`. In order to prevent this situation, modulation provides the
`Module#alias_method_once` method, which prevents aliasing the original method
more than once:

```ruby
module ::Kernel
  # alias_method_once is idempotent
  alias_method_once :orig_sleep, :sleep

  def sleep(duration)
    STDERR.puts "Going to sleep..."
    orig_sleep(duration)
    STDERR.puts "Woke up!"
  end
end
```

## Coding style recommendations

* Import modules into constants, not variables:

  ```ruby
  Settings = import('./settings')
  ```

* Place your exports at the top of your module, followed by `#require`s,
  followed by `#import`s:

  ```ruby
  export :foo, :bar, :baz

  require 'json'

  Core = import('./core')

  ...
  ```

## API Reference

This section will be expanded on in a future release.

#### `__module_info`

### `__reload!`

#### `alias_method_once()`

#### `auto_import()`

#### `auto_import_map()`

#### `export()`

#### `export_default()`

#### `export_from_receiver()`

#### `extend_from()`

#### `import()`

#### `import_all()`

#### `import_map()`

#### `include_from()`

#### `Modulation.full_backtrace!`

#### `Modulation.reload()`

#### `MODULE`

#### `MODULE.__module_info`

## Why you should not use Modulation

- Modulation is not production-ready.
- Modulation is not thread-safe.
- Modulation doesn't play well with rdoc/yard.
- Modulation (probably) doesn't play well with `Marshal`.
- Modulation (probably) doesn't play well with code-analysis tools.
