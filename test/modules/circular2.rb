export :MOL, :reexported

MOL = 42

C1 = import('circular1')

def reexported
  C1.meaning_of_life
end

