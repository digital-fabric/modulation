Lancelot = import('./lancelot')
Robin = import('./robin')

def ask(m)
  puts "Asking #{m.name}..."
  print "What is your name? "
  puts m.name
  print "What is your quest? "
  puts m.quest
  if m.name =~ /Robin/
    print "What is the capital of assyria? "
    puts m.capital_of_assyria
  else
    print "What is your favorite colour? "
    puts m.favorite_colour
  end
rescue
  puts "I don't know that! Aaaaaaaaagh!"
end

def main
  ask(Lancelot)
  ask(Robin)
end