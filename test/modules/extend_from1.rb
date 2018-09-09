export :method1, :FOO

def method1
  secret
end

def secret
  1
end

FOO = :bar