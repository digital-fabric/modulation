export :message, :sql_const

Mocked = import('./mocked')

def message
  Mocked.message
end

def sql_const
  Mocked::SQL
end