Counter = import './counter'

def main
  raise 'blah'
  puts "incrementing..."
  Counter.incr
  puts "reloaded? #{Counter.reloaded?}"
  puts "value: #{Counter.value}"
  puts "reloading..."
  Counter.__reload!
  puts "reloaded? #{Counter.reloaded?}"
  puts "value: #{Counter.value}"
end