# frozen_string_literal: true

# Kernel extensions
module Kernel
  CALLER_RANGE = (1..1).freeze

  # Imports a module
  # @param path [String] module file name
  # @param caller_location [String] caller location
  # @return [Module] module object
  def import(path, caller_location = caller(CALLER_RANGE).first)
    Modulation.import(path, caller_location)
  end

  # Imports all modules in given directory
  # @param path [String] directory path
  # @param caller_location [String] caller location
  # @return [Array] array of module objects
  def import_all(path, caller_location = caller(CALLER_RANGE).first)
    Modulation.import_all(path, caller_location)
  end

  # Imports all modules in given directory, returning a hash mapping filenames
  # to modules
  # @param path [String] directory path
  # @param caller_location [String] caller location
  # @return [Hash] hash mapping filenames to module objects
  def import_map(path, options = {},
                 caller_location = caller(CALLER_RANGE).first)
    Modulation.import_map(path, options, caller_location)
  end

  def auto_import_map(path, options = {},
                      caller_location = caller(CALLER_RANGE).first)
    Modulation.auto_import_map(path, options, caller_location)
  end
end

# Module extensions
class Module
  # Registers a constant to be lazy-loaded upon lookup
  # @param sym [Symbol, Hash] constant name or hash mapping names to paths
  # @param path [String] path if sym is Symbol
  # @return [void]
  def auto_import(sym, path = nil, caller_location = caller(CALLER_RANGE).first)
    setup_auto_import_registry unless @__auto_import_registry
    if path
      @__auto_import_registry[sym] = [path, caller_location]
    else
      sym.each { |k, v| @__auto_import_registry[k] = [v, caller_location] }
    end
  end

  def setup_auto_import_registry
    @__auto_import_registry = {}
    Modulation::Builder.define_auto_import_const_missing_method(
      self,
      @__auto_import_registry
    )
  end

  # Extends the receiver with exported methods from the given file name
  # @param path [String] module filename
  # @return [void]
  def extend_from(path)
    mod = import(path, caller(CALLER_RANGE).first)
    Modulation::Builder.add_module_methods(mod, self.singleton_class)
    Modulation::Builder.add_module_constants(mod, self)
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param path [String] module filename
  # @param symbols [Array<Symbol>] list of symbols to include
  # @return [void]
  def include_from(path, *symbols)
    mod = import(path, caller(CALLER_RANGE).first)
    Modulation::Builder.add_module_methods(mod, self, *symbols)
    Modulation::Builder.add_module_constants(mod, self, *symbols)
  end

  # Aliases the given method only if the alias does not exist, implementing in
  # effect idempotent method aliasing
  # @param new_name [Symbol] alias name
  # @param old_name [Symbol] original name
  # @return [Module] self
  def alias_method_once(new_name, old_name)
    return self if method_defined?(new_name)

    alias_method(new_name, old_name)
  end
end

if Object.constants.include?(:Rake)
  Rake::DSL.alias_method :rake_import, :import rescue nil
  Rake::DSL.remove_method :import rescue nil
end
