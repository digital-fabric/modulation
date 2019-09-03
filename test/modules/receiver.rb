export :foo
export_from_receiver :Bar

def foo
  Bar.foo
end

class Bar
  MOL = 42

  def self.foo
    :foo
  end

  def self.bar
    baz
  end

  class << self
    private

    def baz
      :baz
    end
  end
end
