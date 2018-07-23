require_relative '../../lib/modulation/gem'

export_default :MyGem

module MyGem
  CONST = import('default_module/const')
  MyClass = import('default_module/imported_class')
end