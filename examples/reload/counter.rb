# frozen_string_literal: true

export :value, :incr, :reloaded?

@reloaded = !!@counter
@counter ||= 0

def value
  @counter
end

def incr
  @counter += 1
end

def reloaded?
  @reloaded
end
