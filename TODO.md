## Define root path for non-relative paths

```ruby
Modulation.root = 'lib' # automatically expand path to aboslute path

import('support/mod') # absolute ref, expands to lib/support/mod
```

But this might break once importable gems are used. Maybe a better solution
would be to define the root inside a block:

```ruby
Modulation.with('lib') do
  DNS = import('dns')
  DB  = import('db')
end
```

But actually, I'm not so sure this is such a useful thing. I think a more
sensible solution to using non-relative paths is to treat non-relative paths as
gem refs, and all relative paths as, well, relative.

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
      when /^[A-Z]/;  s.const_set(k, v)
      when /^@/;      s.instance_variable_set(k, v)
      else
        s.define_method(k, v.respond_to?(:to_proc) ? v : -> {v})
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

Will necessitate a dependency on a watcher - and this might lead to
complications if a reactor lib (nuclear, async, EM etc) is used.

API:

```ruby
# auto-reload any loaded module if changed
Modulation.auto_reload

# auto-reload specific dirs
Modulation.auto_reload('lib/**/*.rb', 'vendor/**/*.rb')
```
