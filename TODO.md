## add export_all method

Example:

```ruby
# node_types.rb
export_all

GROUP = 1
POINT = 2
ALARM = 3
```

## Add auto_import without arguments

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

### 1.1

- Deal with things like auto_import, auto_import_map
- include app's Gemfile in packed app
- propagated reload (reload all dependents of a reloaded module)
- reload all/changed
- add support for packing assets
- pack reality into single file with all assets

### 1.2

- hooks: before_load, after_load etc

## Packer

- filename obfuscation: use MD5 hash on the filename. When doing an import,
  compare with the MD5 hash of the given path with the dictionary, then proceed
  normally.

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

API:

```ruby
# auto-reload any loaded module if changed
Modulation.reload_updated!

# auto-reload specific dirs
Modulation.reload_updated!('./lib/**/*.rb', './vendor/**/*.rb')

# return a list of updated modules
Modulation.updated_modules

```

Do a `File.stat` on the module when loading it. Whenever `reload_updated!` is
called, go over all loaded modules and compare the stat. If `Errno::ENOENT` is
raised, remove the module.