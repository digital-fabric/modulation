require 'modulation'

calc = import('./calc')

[:add, :mul, :pow].each do |op|
  puts "#{op}: #{calc.(op, 2, 3)}"
end