require 'modulation'

def ask(m)
  puts "What is your name? #{m.name}"
  puts "What is your quest? #{m.quest}"
  puts "What is your favorite colour? #{m.favorite_colour}"
end

Lancelot = import('./lancelot')
ask(Lancelot)