export :a, :b, :C

def a; :a; end
def b; c; end
def c; :b; end

class C
  def foo; :bar; end
end

module D
end