* Define root path for non-relative paths

  ```ruby
  Modulation.root = 'lib' # automatically expand path to aboslute path

  import('support/mod') # absolute ref, expands to lib/support/mod
  ```

* Dependency injections

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

* Re-exporting methods and constants

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

* The Hash-to-singleton pattern (like a Javascript literal object)
  (https://jrsinclair.com/articles/2018/how-to-deal-with-dirty-side-effects-in-your-pure-functional-javascript/)

  ```ruby
  def effect(f)
    {
      map:          ->(g)  { effect.(->(*x) {g.(f.(*x))}) },
      run_effects:  ->(*x) { f.(*x) },
      join:         ->(*x) { f.(*x) },
      chain:        ->(g)  { effect.(f).map(g).join() }
    }.to_singleton
  end

  # implementation
  class Hash
    def to_singleton
      Module.new.tap do |m|
        m.extend(m)
        each do |k, v|
          case k
          when /^[A-Z]/
            m.const_set(k, v)
          when /^@/
            m.instance_variable_set(k, v)
          else
            m.define_method(k, v.respond_to?(:to_proc) ? v : proc {v})
          end
        end
      end
    end
  end
  ```

* Module mocking for tests

  ```ruby
  Modulation.mock('df', MockModule) do
    run_my_tests
  end
  ```

  Or:

  ```ruby
  def setup
    Modulation.mock('df')
  end

  def teardown
    Modulation.unmock('df')
  end

  def test
    ...
  end
  ```

  