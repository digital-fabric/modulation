# Callable module

A callable object in Ruby is one that implements the `#call` method and can be
invoked using the `.(...)` syntax, e.g.:

```ruby
class Adder
  def self.call(x, y)
    x + y
  end
end

Adder.(2, 3) #= 5
```

Alternatively, an object might implement a #to_proc so it could be passed to
arbitrary methods as a block:

```ruby
class Square
  def self.to_proc
    proc { |x| x * X }
  end
end

[1, 2, 3].map(&Square) #=> [1, 4, 9]
```

In the present example, the [imported module](factorial.rb) implements both
`#call` and `#to_proc` and the [application](app.rb) makes use of both to
calculate factorials.