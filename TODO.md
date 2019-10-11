## add export_all method

Example:

```ruby
# node_types.rb
export_all

GROUP = 1
POINT = 2
ALARM = 3
```

## Add auto_import without 

*lib/foo/bar.rb*
```ruby
export baz: 42
```

*app.rb*
```ruby
# auto_import with no arguments means import all from __dir__
auto_import

# passing a path sets the root directory for imports
auto_import './lib'

# an alternative, to do auto_import for an entire project
Modulation.auto_import

# passing an argument to auto_import sets the root directory for imports
Modulation.auto_import './lib'

def main
  # If foo.rb is found, it is loaded into Foo. In the present example, there's a
  # foo directory, so it Foo is set to an empty module, with a #const_missing
  # method that does auto-importing. Foo::Bar then causes the loading of
  # lib/foo/bar.rb, and Bar is set to the loaded module.
  # and 
  puts Foo::Bar.baz
end
```

## Roadmap

### 0.34

- rewrite README:
  - update Ruby core docs links to version 2.6.5
  - reorganize guide into basic usage, advanced features
  - write API reference
- Write post on reddit, rubyflow, dev.to/ruby, news.ycombinator.com

### 1.0

- convert *all* reality codebase to using Modulation + Affect.

### 1.1

- include app's Gemfile in packed app
- propagated reload (reload all dependents of a reloaded module)
- reload all/changed
- add support for packing assets
- pack reality into single file with all assets

### 1.2

- hooks: before_load, after_load etc

## reload all

Add `Modulation.reload_all!` method that reloads all currently loaded modules.
Reloading should be ordered according to the dependencies involved. So, first we
go through each module, and place it before all its dependents, so it will be
reloaded before its dependents.

We can eventually also implement reloading for only changed files:

```ruby
Modulation.reload_changed!
```

See below...

## Packer

- filename obfuscation: use MD5 hash on the filename. When doing an import,
  compare with the MD5 hash of the given path with the dictionary, then proceed
  normally.

## Creating modules on the fly

```ruby
# using eg
m = Modulation.create a: ->(x) { x + 1 }, b: ->(x) { x * 2}

# from string
m = Modulation.create <<~RUBY<<~EOF, 
export :foo

def foo
  :bar
end
EOF

# from block
m = Modulation.create do { |mod|
  export :foo

  def foo
    :bar
  end

  class mod::BAZ
    ...
  end
}
```

## Re-exporting methods and constants

```ruby
# re-export constant
Async = import('async')
Promise = Async::Promise

export :Promise

# re-export method
Async = import('async')
export Async.method(:async)

# or maybe
Async = import('async')
export_from_receiver :Async
```

## Auto-reload changed files:

Will necessitate a dependency on a watcher - and this might lead to
complications if a reactor lib (nuclear, async, EM etc) is used.

API:

```ruby
# auto-reload any loaded module if changed
Modulation.reload_changed!

# auto-reload specific dirs
Modulation.reload_changed!('./lib/**/*.rb', './vendor/**/*.rb')
```
