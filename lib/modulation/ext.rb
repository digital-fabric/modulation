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

  # Imports all modules in given directory, returning a hash mapping filenames
  # to modules
  # @param path [String] directory path
  # @param caller_location [String] caller location
  # @return [Hash] hash mapping filenames to module objects
  def import_map(path, caller_location = caller(1..1).first, &block)
    Modulation.import_map(path, caller_location, &block)
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
      @__auto_import_registry = {}
      Modulation.define_auto_import_const_missing_method(
        self,
        @__auto_import_registry
      )
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
    Modulation.add_module_methods(mod, self.class)
    Modulation.add_module_constants(mod, self)
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param path [String] module filename
  # @param symbols [Array<Symbol>] list of symbols to include
  # @return [void]
  def include_from(path, *symbols)
    mod = import(path, caller(1..1).first)
    Modulation.add_module_methods(mod, self, *symbols)
    Modulation.add_module_constants(mod, self, *symbols)
  end
end

if Object.constants.include?(:Rake)
  Rake::DSL.alias_method :rake_import, :import
  Rake::DSL.remove_method :import
end
