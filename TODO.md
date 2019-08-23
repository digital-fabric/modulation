## Roadmap

### 1.0

- Add auto_import_map for lazy loading into map
- include app's Gemfile in packed app
- propagated reload (reload all dependents of a reloaded module)
- convert *all* reality codebase to using Modulation + Affect.

### 1.1

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

## Packer

- filename obfuscation: use MD5 hash on the filename. When doing an import,
  compare with the MD5 hash of the given path with the dictionary, then proceed
  normally.

## Creating modules on the fly

```ruby
# using eg
m = Modulation.new a: ->(x) { x + 1 }, b: ->(x) { x * 2}

# from string
m = Modulation.new <<~RUBY
export :foo

def foo
  :bar
end
RUBY

# from block
m = Modulation.new do { |mod|
  export :foo

  def foo
    :bar
  end

  class mod::BAZ
    ...
  end
}
```

- raise on missing `export` or `export_default`
- if `export_default` refers to a method, turn it into a proc

## Re-exporting methods and constants

```ruby
# re-export constant
Async = import('async')
Promise = Async::Promise

export :Promise

# re-export method
export Async.method(:async)
```

* Exporting a Hash

```ruby
# procs are converted to module methods
export  async: -> { ... },
        await: ->(promise) { ... }
```

## Auto-reload changed files:

Will necessitate a dependency on a watcher - and this might lead to
complications if a reactor lib (nuclear, async, EM etc) is used.

API:

```ruby
# auto-reload any loaded module if changed
Modulation.auto_reload

# auto-reload specific dirs
Modulation.auto_reload('lib/**/*.rb', 'vendor/**/*.rb')
```
