export :call, :to_proc

def call(n)
  n == 0 ? 1 : n * call(n - 1)
end

# Called when using the & operator
def to_proc
  proc {|n| call(n)}
end