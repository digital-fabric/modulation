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
    mod.singleton_class.instance_methods(false).each do |sym|
      self.class.send(:define_method, sym, mod.method(sym).to_proc)
    end

    mod.singleton_class.constants(false).each do |sym|
      next if sym == :MODULE
      const_set(sym, mod.singleton_class.const_get(sym))
    end
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param path [String] module filename
  # @return [void]
  def include_from(path)
    mod = import(path, caller(1..1).first)
    exported_symbols = mod.__module_info[:exported_symbols]

    mod.singleton_class.instance_methods(false).each do |sym|
      send(:define_method, sym, &mod.method(sym))
    end

    mod.singleton_class.constants(false).each do |sym|
      next unless exported_symbols.include?(sym)
      const_set(sym, mod.singleton_class.const_get(sym))
    end
  end
end
