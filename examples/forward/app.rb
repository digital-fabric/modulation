require 'modulation'

Forwarder = import('./forwarder')
Forwarder.receiver = Time

puts "The time is: #{Forwarder.now}"
