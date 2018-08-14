export :call_me, :hide_and_seek, :reload_dependency

M = import('./reloaded')

def call_me
  M::NAME
end

def hide_and_seek
  M.hide_and_seek
end

def reload_dependency
  M.__reload!
end