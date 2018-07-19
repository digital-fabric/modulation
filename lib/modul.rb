require 'fileutils'
# frozen_string_literal: true

# Kernel extensions - modul's API
module Kernel
  # Returns an encapsulated imported module.
  # @param fn [String] module file namew
  # @return [Class] module facade
  def import(fn)
    Modul.import_module(fn, caller)
  end
end

# Object extensions
class Object
  # Returns the objects metaclass (shamelessly stolen from the metaid gem).
  # @return [Class] object's metaclass
  def metaclass; class << self; self; end; end
end

class Modul
  @@loaded_modules = {}

  # Imports a module from a file
  # If the module is already loaded, returns the loaded module.
  # @param fn [String] source file name (with or without extension)
  # @return [Module] loaded module object
  def self.import_module(fn, caller_stack = caller)
    fn = module_absolute_path(fn, caller_stack)
    @@loaded_modules[fn] ||= create_module_from_file(fn)
  end

  def self.module_absolute_path(fn, caller_stack)
    caller_file = (caller_stack.first =~ /^([^\:]+)\:/) ?
      $1 : (raise "Could not expand path")
    fn = File.expand_path(fn, File.dirname(caller_file))
    if File.file?("#{fn}.rb")
      fn = fn + '.rb'
    else
      raise "Module not found: #{fn}" unless File.file?(fn)
    end
    fn
  end

  # Creates a new module from a source file
  # @param fn [String] source file name
  # @return [Module] module
  def self.create_module_from_file(fn)
    make_module(location: fn)
  rescue => e
    # remove *modul* methods from backtrace and reraise
    backtrace = e.backtrace.reject {|l| l.include?(__FILE__)}
    raise(e, e.message, backtrace)
  end

  # Loads a module from file or block, wrapping it in a module facade
  # @param info [Hash] module info
  # @param block [Proc] module block
  # @return [Class] module facade
  def self.make_module(info, &block)
    export_default = nil
    m = initialize_module {|v| export_default = v}
    m.__module_info = info
    load_module_code(m, info, &block)

    if export_default
      transform_export_default_value(export_default, m)
    else
      m.tap {m.__set_exported_symbols(m, m.__exported_symbols)}
    end
  end

  # Returns exported value for a default export
  # If the given value is a symbol, returns the value of the corresponding
  # constant.
  # @param value [any] export_default value
  # @param mod [Module] module
  # @return [any] exported value
  def self.transform_export_default_value(value, mod)
    if value.is_a?(Symbol) && mod.const_defined?(value)
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
      m.extend(ModuleMethods)
      m.metaclass.include(ModuleMetaclassMethods)
      m.__export_default_block = export_default_block
    end
  end

  # Loads a source file or a block into the given module
  # @param m [Module] module
  # @param fn [String] source file path
  # @return [void]
  def self.load_module_code(m, info)
    fn = info[:location]
    m.instance_eval(IO.read(fn), fn)
  end

  # Module façade methods
  module ModuleMethods
    # Responds to missing constants by checking metaclass
    # If the given constant is defined on the metaclass, the same constant is
    # defined on self and its value is returned. This is essential to
    # supporting constants in modules.
    # @param name [Symbol] constant name
    # @return [any] constant value
    def const_missing(name)
      if metaclass.const_defined?(name)
        unless !@__exported_symbols || @__exported_symbols.include?(name)
          raise NameError, "private constant `#{name}' accessed in #{inspect}", caller
        end
        metaclass.const_get(name).tap {|value| const_set(name, value)}
      else
        raise NameError, "uninitialized constant #{inspect}::#{name}", caller
      end
    end

    # read and write module information
    attr_accessor :__module_info

    # Sets exported_symbols ivar and marks all non-exported methods as private
    # @param m [Module] imported module
    # @param symbols [Array] array of exported symbols
    # @return [void]
    def __set_exported_symbols(m, symbols)
      @__exported_symbols = symbols
      metaclass.instance_methods(false).each do |m|
        metaclass.send(:private, m) unless symbols.include?(m)
      end
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
  end

  # Module façade metaclass methods
  module ModuleMetaclassMethods
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
      @__export_default_block.call(v) if @__export_default_block
    end

    # read and write module info
    attr_accessor :__module_info

    # Returns exported_symbols array
    # @return [Array] array of exported symbols
    def __exported_symbols
      @exported_symbols ||= []
    end

    # Sets export_default block, used for setting the returned module object to
    # a class or constant
    # @param block [Proc] default export block
    # @return [void]
    def __export_default_block=(block)
      @__export_default_block = block
    end
  end
end
