# frozen_string_literal: true

Counter = import './counter'

def main
  puts 'incrementing...'
  Counter.incr
  puts "reloaded? #{Counter.reloaded?}"
  puts "value: #{Counter.value}"
  puts 'reloading...'
  Counter.__reload!
  puts "reloaded? #{Counter.reloaded?}"
  puts "value: #{Counter.value}"
end
