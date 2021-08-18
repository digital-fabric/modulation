export :call, :to_proc

def call(x)
  x**2
end

def to_proc
  proc { :foo }
end
