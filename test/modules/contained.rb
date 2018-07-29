export :meaning_of_life, :ContainedModule

def meaning_of_life
  42
end

def private_method
  "private"
end

module ContainedModule
  def self.test
    MODULE.meaning_of_life
  end

  def self.test_private
    MODULE.private_method
  end
end
