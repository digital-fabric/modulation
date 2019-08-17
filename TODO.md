- raise on missing `export` or `export_default`
- if `export_default` refers to a method, turn it into a proc

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

## Auto-compiling and caching of modules

Objective:

- Faster loading of modules
- Compilation of ruby apps into a single file without source code, with [inline `gemfile`](https://bundler.io/v1.17/guides/bundler_in_a_single_file_ruby_script.html)
- Perhaps also a simplificatio of how modules are loaded - be able to use `eval`
  instead of `instance_eval`.
  
Compiling to a single file:

- `compile` takes a single path
- when an `import` is encountered, the module is inlined, then saved into a
  `__MODULES__` hash cache. Whenever the module is imported again, it's loaded 
  from the cache.
- The different modules are therefore inlined into a single body of source code,
  which is then compiled into an `iseq`.
- The Iseq is converted to binary representation and zipped.
- The zipped binary code is written to the `DATA` section of a ruby file, along
  with a short preamble loading the `DATA` section, unzipping it, loading the
  `iseq` from the binary data, and finally `eval`ing the `iseq`.