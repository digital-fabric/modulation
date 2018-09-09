## Define root path for non-relative paths

```ruby
Modulation.root = 'lib' # automatically expand path to aboslute path

import('support/mod') # absolute ref, expands to lib/support/mod
```

## Dependency injection - service registry

```ruby
# bootstrap.rb
Modulation[:timeline] = import('timeline')
...

# nodes.rb
Modulation[:timeline].insert(...)
```

Issue warning on probable collision:

```ruby
Modulation[:timeline] = import('timeline')
...
Modulation[:timeline] = import('timeline') #=> Warning: timeline service already set
```

Raise on missing service:

```ruby
Modulation[:whatever] #=> NameError: unknown service `whatever' referenced
```

Mock dependency:

```ruby
Modulation.mock(:timeline, MockTimeline) do

end
```

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

## The Hash-to-singleton pattern (like a Javascript literal object)
(https://jrsinclair.com/articles/2018/how-to-deal-with-dirty-side-effects-in-your-pure-functional-javascript/)

```ruby
def effect(f)
  hash_to_singleton(
    map:          ->(g)  { effect.(->(*x) {g.(f.(*x))}) },
    run_effects:  ->(*x) { f.(*x) },
    join:         ->(*x) { f.(*x) },
    chain:        ->(g)  { effect.(f).map(g).join() }
  )
end

# implementation
def hash_to_singleton(h)
  Module.new.tap do |m|
    s = m.singleton_class
    h.each do |k, v|
      case k
      when /^[A-Z]/
        s.const_set(k, v)
      when /^@/
        s.instance_variable_set(k, v)
      else
        s.define_method(k, v.respond_to?(:to_proc) ? v : proc {v})
      end
    end
  end
end

f_zero = -> {
  puts 'Starting with nothing'
  0
}
```

## Auto-reload changed files:

API:

```ruby
# auto-reload any loaded module if changed
Modulation.auto_reload

# auto-reload specific dirs
Modulation.auto_reload('lib/**/*.rb', 'vendor/**/*.rb')
```

## command line for running Ruby with modulation preloaded, and loading files as modules

## Importing specific symbols from module

```ruby
Core, Net = import('nuclear')[:Core, :Net]

# or
import('nuclear').bind(self, :Core, :Net)

# but easiest is probably
include_from('nuclear')
Core
Net

```

## Package manager?

What are the problems with rubygems?

- It's slow!
- Since every loaded gem is added to the $LOAD_PATH, when more gems are used, file loading becomes slower
- Because of $LOAD_PATH, gems can easily trample over each other
- No explicit dependencies
- 