# frozen_string_literal: true

require 'modulation'

calc = import('./calc')

%i[add mul pow].each do |op|
  puts "#{op}: #{calc.(op, 2, 3)}"
end
