add = ->(x, y) { x + y }
mul = ->(x, y) { x * y}
pow = ->(x, y) { x ** y }

export_default ->(op, x, y) {
  case op
  when :add
    add.(x, y)
  when :mul
    mul.(x, y)
  when :pow
    pow.(x, y)
  else
    raise "Invalid op"
  end
}