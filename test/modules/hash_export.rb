export  Everything: 42,
        foo:        :bar,
        bar:        :Baz,
        greeting:   -> name { "Hello #{name}!" }

def bar
  :baz
end

Baz = 'ZZZ'
