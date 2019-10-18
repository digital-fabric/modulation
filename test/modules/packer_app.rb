Thread.current[:inc] = 0
b1 = import('./b1')

def main
  puts Thread.current[:inc]
end