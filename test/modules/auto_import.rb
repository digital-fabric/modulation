export :foo

auto_import :BAR, './auto_import_bar'

def foo
  MODULE::BAR
end
