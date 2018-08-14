require 'modulation'

def ask(m)
  puts "What is your name? #{m.name}"

  puts "What is your quest? #{m.quest}"

  puts "What is your favorite color? #{m.favorite_color}"
end

Lancelot = import('./lancelot')
ask(Lancelot)