Modulation.add_tags handlers: './handlers'

def main
  add = import('@handlers/add')
  mul = import('@handlers/mul')
  
  puts "add(2, 3): #{add.(x: 2, y: 3)}"
  puts "mul(2, 3): #{mul.(x: 2, y: 3)}"
end
