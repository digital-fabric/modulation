# frozen_string_literal: true

export :call, :to_proc

def call(n)
  n.zero? ? 1 : n * call(n - 1)
end

# Called when using the & operator
def to_proc
  proc { |n| call(n) }
end
