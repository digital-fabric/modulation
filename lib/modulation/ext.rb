# frozen_string_literal: true

# Kernel extensions
module Kernel
  # Returns an encapsulated imported module.
  # @param path [String] module file name
  # @param caller_location [String] caller location
  # @return [Class] module facade
  def import(path, caller_location = caller(1..1).first)
    Modulation.import(path, caller_location)
  end
end

# Module extensions
class Module
  # Extends the receiver with exported methods from the given file name
  # @param path [String] module filename
  # @return [void]
  def extend_from(path)
    mod = import(path, caller(1..1).first)
    add_module_methods(mod, self.class)
    add_module_constants(mod, self)
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param path [String] module filename
  # @return [void]
  def include_from(path)
    mod = import(path, caller(1..1).first)
    add_module_methods(mod, self)
    add_module_constants(mod, self)
  end

  def add_module_methods(mod, target)
    mod.singleton_class.instance_methods(false).each do |sym|
      target.send(:define_method, sym, &mod.method(sym))
    end
  end

  def add_module_constants(mod, target)
    exported_symbols = mod.__module_info[:exported_symbols]
    mod.singleton_class.constants(false).each do |sym|
      next unless exported_symbols.include?(sym)
      target.const_set(sym, mod.singleton_class.const_get(sym))
    end
  end
end
