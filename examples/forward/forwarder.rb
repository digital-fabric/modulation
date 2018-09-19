export :receiver=

def receiver=(receiver)
  @receiver = receiver
end

def method_missing(sym, *args, &block)
  @receiver.send(sym, *args, &block)
end