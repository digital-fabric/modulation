# frozen_string_literal: true

require 'modulation'

def ask(mod)
  puts "What is your name? #{mod.name}"
  puts "What is your quest? #{mod.quest}"
  puts "What is your favorite colour? #{mod.favorite_colour}"
end

Lancelot = import('./lancelot')
ask(Lancelot)
