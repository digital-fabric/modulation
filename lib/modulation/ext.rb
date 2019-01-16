# frozen_string_literal: true

# Kernel extensions
module Kernel
  # Imports a module
  # @param path [String] module file name
  # @param caller_location [String] caller location
  # @return [Module] module object
  def import(path, caller_location = caller(1..1).first)
    Modulation.import(path, caller_location)
  end

  # Imports all modules in given directory
  # @param path [String] directory path
  # @param caller_location [String] caller location
  # @return [Array] array of module objects
  def import_all(path, caller_location = caller(1..1).first)
    Modulation.import_all(path, caller_location)
  end
end

# Module extensions
class Module
  # Registers a constant to be lazy-loaded upon lookup
  # @param sym [Symbol, Hash] constant name or hash mapping names to paths
  # @param path [String] path if sym is Symbol
  # @return [void]
  def auto_import(sym, path = nil, caller_location = caller(1..1).first)
    unless @__auto_import_registry
      a = @__auto_import_registry = {}
      define_auto_import_const_missing_method(@__auto_import_registry)
    end
    if path
      @__auto_import_registry[sym] = [path, caller_location]
    else
      sym.each { |k, v| @__auto_import_registry[k] = [v, caller_location] }
    end
  end

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

  private

  def define_auto_import_const_missing_method(auto_import_hash)
    singleton_class.define_method(:const_missing) do |sym|
      (path, caller_location) = auto_import_hash[sym]
      path ? const_set(sym, import(path, caller_location)) : super
    end
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
