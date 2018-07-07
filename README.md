# modul

modul provides an alternative way to organize your code. Instead of littering the global namespace with classes and modules, you can organize your code using enclosed, well-separated modules. This way of organizing code might look more natural for code bases leaning towards functional programming. Loading modules with modul resembles in some ways the functionality provided by Python, node.js, Go and other programming languages.

## What benefits does it offer?

- Explicit code dependencies (each module needs to be explicitly imported in each place it is used).
- Better code separation (code can be split into smaller, well defined parts)
- Less boilerplate (no more deeply nested class namespaces, singleton classes or `class << self`)
- Suitable for functional-style programming.

## What are the limitations of using modul?

- Doesn't play well with gems (i.e., currently there's no easy way to import a 'gem')
- Doesn't play well with `require`
- Doesn't play well with code-analysis tools like SolarGraph

## What does it look like?

```ruby
# fib.rb
def fibonacci(n)
  case
  when 0, 1
    n
  else
    (fibonacci(n - 1) + fibonacci(n - 2))
  end
end

# hello_world.rb
require 'modul'
fib = import('./fib')
puts fib.fibonacci(10)
```

## Does it support private methods?

Yes:

```ruby
# foo.rb
def foo
  bar
end

private

def bar
  "hello"
end

# private_method_call.rb
foo = import('./foo')
foo.foo #=> "hello"
foo.bar #=> NoMethodError: private method `bar' called...
```

## Does it support class, module and constant definitions?

Yes:

```ruby
# mod.rb
MEANING_OF_LIFE = 42

class C
  def foo; "bar"; end
end

# meaner.rb
mod = import('./mod')
mod::MEANING_OF_LIFE #=> 42

c = mod::C.new
c.foo #=> "bar"
```
