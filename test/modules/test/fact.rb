export :fact

def fact(n)
  n == 0 ? 1 : n * call(n - 1)
end

# test :factorial do
#   scenario :a do
#     assert fact(0) == 1
#     assert fact(1) == 1
#     assert fact(2) == 2
#     assert fact(3) == 6
#     assert fact(4) == 24
#     assert fact(5) == 120
#   end
# end