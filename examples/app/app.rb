# frozen_string_literal: true

Lancelot = import('./lancelot')
Robin = import('./robin')

def ask(mod)
  puts "Asking #{mod.name}..."
  print 'What is your name? '
  puts mod.name
  print 'What is your quest? '
  puts mod.quest
  if mod.name =~ /Robin/
    print 'What is the capital of assyria? '
    puts mod.capital_of_assyria
  else
    print 'What is your favorite colour? '
    puts mod.favorite_colour
  end
rescue StandardError
  puts "I don't know that! Aaaaaaaaagh!"
end

def main
  ask(Lancelot)
  ask(Robin)
end
