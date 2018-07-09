# Modul - better dependencies for Ruby

Modul provides an alternative way to organize Ruby code. Instead of littering 
the global namespace with classes and modules, Mrodul lets you explicitly 
import and export declarations in order to better control dependencies in your 
codebase.

With Modul, you always know where a module comes from, and you have full 
control over which parts of a module's code you wish to expose to the outside 
world. With Modul, you can more easily write in a functional style with a 
minimum of boilerplate code.

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

So I came up with Modul, a small gem that takes a different approach to 
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
require 'modul'
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
require 'modul'
Seq = import('./seq')
puts Seq.fib(10)
```

### Importing declarations

Declarations from another module can be imported using `import`:

```ruby
require 'modul'
Models = import('./models')
...

user = Models::User.new(...)

...
```

Alternatively, a module interested in a single declaration from another module 
can use the following technique:

```ruby
require 'modul'
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

> **Note about namespaces**: defining a namespace will prevent access to any 
methods or classes contained in that namespace, even from the same file, 
unless they are *explicitly* exported.

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

## Coding style recommendations

* Import modules into constants, not into variables:

  ```ruby
  Settings = import('./settings')
  ```

* Place your exports at the top of your module or namespace:

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

* If coding in functional style (i.e. no instance variables), use namespaces to
  separate between functionalities:

  ```ruby
  namespace :Subscriptions do
    ...
  end

  namespace :Events do
     ...
  end

  ...
  ```

## Known limitations and problems

- Modul is not production-ready.
- Modul might cause a mess if used to import gems.
- Modul doesn't play well with `Marshal`.
- Modul probably doesn't play well with code-analysis tools.