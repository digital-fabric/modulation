# frozen_string_literal: true
require 'fileutils'

# Kernel extensions
module Kernel
  # Returns an encapsulated imported module.
  # @param fn [String] module file name
  # @param caller_location [String] caller location
  # @return [Class] module facade
  def import(fn, caller_location = caller.first)
    Modulation.import_module(fn, caller_location)
  end
end

# Module extensions
class Module
  # Exports symbols from a namespace module declared inside an importable
  # module. Exporting the actual symbols is deferred until the entire code
  # has been loaded
  # @param symbols [Array] array of symbols
  # @return [void]
  def export(*symbols)
    unless Modulation.__top_level_module__
      raise NameError, "Can't export symbols outside of an imported module"
    end

    extend self
    Modulation.__top_level_module__.__defer_namespace_export(self, symbols)
  end

  # Extends the receiver with exported methods from the given file name
  # @param fn [String] module filename
  # @return [void] 
  def extend_from(fn)
    mod = import(fn, caller.first)
    mod.instance_methods(false).each do |sym|
      self.class.send(:define_method, sym, mod.method(sym).to_proc)
    end
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param fn [String] module filename
  # @return [void]
  def include_from(fn)
    mod = import(fn, caller.first)
    mod.instance_methods(false).each do |sym|
      send(:define_method, sym, mod.method(sym).to_proc)
    end
  end
end

class Modulation
  # Hash mapping fully-qualified paths to loaded modules
  @@loaded_modules = {}

  # Reference to currently loaded top-level module, used for correctly 
  # exporting symbols from namespaces
  @@top_level_module = nil

  # Flag denoting whether to provide full backtrace on errors during
  # loading of a module (normally Modulation removes stack frames 
  # occuring in Modulation code)
  @@full_backtrace = false

  public

  # Show full backtrace for errors occuring while loading a module. Normally
  # Modulation will remove stack frames occurring inside the modulation.rb code
  # in order to make backtraces more readable when debugging.
  def self.full_backtrace!
    @@full_backtrace = true
  end

  # Imports a module from a file
  # If the module is already loaded, returns the loaded module.
  # @param fn [String] unqualified file name
  # @param caller_location [String] caller location
  # @return [Module] loaded module object
  def self.import_module(fn, caller_location = caller.first)
    fn = module_absolute_path(fn, caller_location)
    @@loaded_modules[fn] || create_module_from_file(fn)
  end

  # Returns the currently loaded top level module
  # @return [Module] currently loaded module
  def self.__top_level_module__
    @@top_level_module
  end

  private

  # Resolves the absolute path to the provided reference. If the file is not
  # found, will try to resolve to a gem
  # @param fn [String] unqualified file name
  # @param caller_location [String] caller location
  # @return [String] absolute file name
  def self.module_absolute_path(fn, caller_location = caller.first)
    orig_fn = fn
    caller_file = (caller_location =~ /^([^\:]+)\:/) ?
      $1 : (raise "Could not expand path")
    fn = File.expand_path(fn, File.dirname(caller_file))
    if File.file?("#{fn}.rb")
      fn + '.rb'
    else
      if File.file?(fn)
        return fn
      else
        lookup_gem(orig_fn) || (raise "Module not found: #{fn}")
      end
    end
  end

  # Resolves the provided file name into a gem. If no gem is found, returns nil
  # @param name [String] gem name
  # @return [String] absolute path to gem main source file
  def self.lookup_gem(name)
    spec = Gem::Specification.find_by_name(name)
    unless(spec.dependencies.map(&:name)).include?('modulation')
      raise NameError, "Cannot import gem not based on modulation"
    end
    fn = File.join(spec.full_require_paths, "#{name}.rb")
    File.file?(fn) ? fn : nil
  rescue Gem::MissingSpecError
    nil 
  end

  # Creates a new module from a source file
  # @param fn [String] source file name
  # @return [Module] module
  def self.create_module_from_file(fn)
    make_module(location: fn)
  rescue => e
    @@full_backtrace ? raise : raise_with_clean_backtrace(e)
  end

  # (Re-)raises an error, filtering its backtrace to remove stack frames
  # occuring in Modulation code
  def self.raise_with_clean_backtrace(e)
    backtrace = e.backtrace.reject {|l| l.include?(__FILE__)}
    raise(e, e.message, backtrace)
  end

  # Loads a module from file or block, wrapping it in a module facade
  # @param info [Hash] module info
  # @param block [Proc] module block
  # @return [Class] module facade
  def self.make_module(info, &block)
    default_value = :__no_default_value__
    default_value_caller = nil
    m = initialize_module do |v, caller|
      default_value = v
      default_value_caller = caller
    end
    @@loaded_modules[info[:location]] = m
    m.__module_info = info
    load_module_code(m, info, &block)
    if default_value != :__no_default_value__
      set_module_default_value(default_value, info, m, default_value_caller)
    else
      m.__perform_deferred_namespace_exports
      set_exported_symbols(m, m.__exported_symbols)
      m
    end
  end

  DEFAULT_VALUE_ERROR_MSG = "Default export cannot be boolean, numeric, or symbol"
  private_constant(:DEFAULT_VALUE_ERROR_MSG)

  # Sets the default value for a module using export_default
  # @param value [any] default value
  # @param info [Hash] module info
  # @param m [Module] module
  # @return [any] default value
  def self.set_module_default_value(value, info, m, caller)
    value = transform_export_default_value(value, m)
    case value
    when nil, true, false, Numeric, Symbol
      raise(TypeError, DEFAULT_VALUE_ERROR_MSG, caller)
    end
    set_reload_info(value, m.__module_info)
    @@loaded_modules[info[:location]] = value
  end

  # Adds methods for module_info and reloading to a value exported as default
  # @param value [any] export_default value
  # @param info [Hash] module info
  # @return [void]
  def self.set_reload_info(value, info)
    value.define_singleton_method(:__module_info) {info}
    value.define_singleton_method(:__reload!) {Modulation.make_module(info)}
  end

  # Returns exported value for a default export
  # If the given value is a symbol, returns the value of the corresponding
  # constant.
  # @param value [any] export_default value
  # @param mod [Module] module
  # @return [any] exported value
  def self.transform_export_default_value(value, mod)
    if value.is_a?(Symbol) && (mod.const_defined?(value) rescue nil)
      mod.const_get(value)
    else
      value
    end
  end

  # Initializes a new module ready to evaluate a file module
  # @note The given block is used to pass the value given to `export_default`
  # @return [Module] new module
  def self.initialize_module(&export_default_block)
    Module.new.tap do |m|
      m.extend(m)
      m.extend(ModuleMethods)
      m.__export_default_block = export_default_block
      m.const_set(:MODULE, m)
    end
  end

  # Loads a source file or a block into the given module
  # @param m [Module] module
  # @param fn [String] source file path
  # @return [void]
  def self.load_module_code(m, info, &block)
    old_top_level_module = @@top_level_module
    @@top_level_module = m
    if block
      m.module_eval(&block)
    else
      fn = info[:location]
      m.module_eval(IO.read(fn), fn)
    end
  ensure
    @@top_level_module = old_top_level_module
  end

  # Sets exported_symbols ivar and marks all non-exported methods as private
  # @param m [Module] module with exported symbols
  # @param symbols [Array] array of exported symbols
  # @return [void]
  def self.set_exported_symbols(m, symbols)
    # m.__exported_symbols = symbols
    m.instance_methods.each do |sym|
      next if symbols.include?(sym)
      m.send(:private, sym)
    end
    m.constants.each do |sym|
      next if sym == :MODULE || symbols.include?(sym)
      m.send(:private_constant, sym)
    end
  end

  # Reloads the given module from its source file
  # @param m [Module, String] module to reload
  # @return [Module] module
  def self.reload(m)
    if m.is_a?(String)
      fn, m = m, @@loaded_modules[File.expand_path(m)]
      raise "No module loaded from #{fn}" unless m
    end
    
    cleanup_module(m)

    orig_verbose, $VERBOSE = $VERBOSE, nil
    load_module_code(m, m.__module_info)
    $VERBOSE = orig_verbose
    
    m.__perform_deferred_namespace_exports
    m.tap {set_exported_symbols(m, m.__exported_symbols)}
  end

  # Removes methods and constants from module
  # @param m [Module] module
  # @return [void]
  def self.cleanup_module(m)
    m.constants(false).each {|c| m.send(:remove_const, c)}
    m.methods(false).each {|sym| m.send(:undef_method, sym)}

    private_methods = m.private_methods(false) - Module.private_instance_methods(false)
    private_methods.each {|sym| m.send(:undef_method, sym)}

    m.__exported_symbols.clear
  end

  # Extension methods for loaded modules
  module ModuleMethods
    # read and write module information
    attr_accessor :__module_info

    # Adds given symbols to the exported_symbols array
    # @param symbols [Array] array of symbols
    # @return [void]
    def export(*symbols)
      symbols = symbols.first if Array === symbols.first
      __exported_symbols.concat(symbols)
    end

    # Sets a module's value, so when imported it will represent the given value,
    # instead of a module facade
    # @param v [Symbol, any] symbol or value
    # @return [void]
    def export_default(v)
      @__export_default_block.call(v, caller) if @__export_default_block
    end

    # Returns a text representation of the module for inspection
    # @return [String] module string representation
    def inspect
      module_name = name || 'Module'
      if __module_info[:location]
        "#{module_name}:#{__module_info[:location]}"
      else
        "#{module_name}"
      end
    end

    # Sets export_default block, used for setting the returned module object to
    # a class or constant
    # @param block [Proc] default export block
    # @return [void]
    def __export_default_block=(block)
      @__export_default_block = block
    end

    # Reload module
    # @return [Module] module
    def __reload!
      Modulation.reload(self)
    end

    # Defers exporting of symbols for a namespace (nested module), to be 
    # performed after the entire module has been loaded
    # @param namespace [Module] namespace module
    # @param symbols [Array] array of symbols
    # @return [void]
    def __defer_namespace_export(namespace, symbols)
      @__namespace_exports ||= Hash.new {|h, k| h[k] = []}
      @__namespace_exports[namespace].concat(symbols)
    end

    # Performs exporting of symbols for all namespaces defined in the module,
    # marking unexported methods and constants as private
    # @return [void]
    def __perform_deferred_namespace_exports
      return unless @__namespace_exports

      @__namespace_exports.each do |m, symbols|
        Modulation.set_exported_symbols(m, symbols)
      end
    end

    # Returns exported_symbols array
    # @return [Array] array of exported symbols
    def __exported_symbols
      @exported_symbols ||= []
    end
  end
end