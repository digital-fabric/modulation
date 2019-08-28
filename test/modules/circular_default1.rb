export_default :C1

C2 = import('./circular_default2')

class C1
  def foo
    C2.new.foo
  end

  def bar
    :baz
  end
end
