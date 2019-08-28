export_default :C2

C1 = import('./circular_default1')

class C2
  def foo
    :bar
  end

  def bar
    C1.new.bar
  end
end
