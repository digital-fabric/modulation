# frozen_string_literal: true

export :receiver=

attr_writer :receiver

def method_missing(sym, *args, &block)
  @receiver.send(sym, *args, &block)
end
