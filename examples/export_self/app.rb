class << (Effects = Module.new)
  Handlers = {
    log: import('./log'),
    say: -> what { puts what },
    ask: -> { STDIN.gets }
  }

  def method_missing(sym, *args)
    Handlers[sym].call(*args)
  end
end

def main
  Effects.log.debug 'Starting...'
  Effects.say "What's your name?"
  name = Effects.ask
  Effects.log.warn 'This is a warning message'
  Effects.say "Hello, #{name}"
  Effects.log.debug 'Done'
end