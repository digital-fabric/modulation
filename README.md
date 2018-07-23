# Modulation - explicit dependencies for Ruby

Modulation provides an alternative way to organize Ruby code. Instead of 
littering the global namespace with classes and modules, Mrodulation lets you 
explicitly import and export declarations in order to better control 
dependencies in your codebase.

With Modulation, you always know where a module comes from, and you have full 
control over which parts of a module's code you wish to expose to the outside 
world. With Modulation, you can more easily write in a functional style with a 
minimum of boilerplate code.

> **Important notice**: Modulation is currently at an experimental stage. Use
> it at your own risk!

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
Math = import('./math')
puts Math.fib(10)
```

## Organizing Ruby code base with Modul

Any Ruby source file can be a module. Modules can export declarations (usually 
an API for a specific functionality) to be shared with other modules. Modules 
can also import declarations from other modules.

Each module is loaded and evaluated in the context of a newly-created `Module`,
then transformed into a class and handed off to the importing module.

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
> calling the `import` method.

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

> **Note**: when loading gems using import, Modulation will raise an exception
> if no symbols were exported by the gem.

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
- Modulation probably doesn't play well with `Marshal`.
- Modulation probably doesn't play well with code-analysis tools.
- Modulation doesn't play well with rdoc/yard.