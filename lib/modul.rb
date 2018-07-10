require 'fileutils'

# Kernel extensions - modul's API
module Kernel
  # Handles calls to export when a module is loaded using `require`
  # @return [void]
  def export(*args)
    # nop
  end

  # Handles calls to export when a module is loaded using `require`
  def export_default(v)
    # nop
  end

  # Returns an encapsulated imported module.
  # @param fn [String] module file name
  # @return [Class] module facade
  def import(fn)
    Modul.import_module(fn)
  end

  # Creates a namespace sub-module and exposes to the outside world if a name
  # is given.
  # @param name [String, nil] namespace name.
  # @param block [Proc] namespace block
  def namespace(name = nil, &block)
    module_info = {
      module: self,
      top_level_module: Modul.top_level_module(self),
      name: name,
      location: caller.first =~ /^([^\:]+\:\d+)/ && $1
    }
    Modul.make_module(module_info, &block)
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
  # @return [ModuleFacade] loaded module object
  def self.import_module(fn)
    if File.file?("#{fn}.rb")
      fn << '.rb'
    else
      raise "Module not found: #{fn}" unless File.file?(fn)
    end
    fn = File.expand_path(fn)
    @@loaded_modules[fn] ||= create_module_from_file(fn)
  end

  # Creates a new module from a source file
  # @param fn [String] source file name
  # @return [ModuleFacade] module
  def self.create_module_from_file(fn)
    pwd = FileUtils.pwd
    FileUtils.chdir(File.dirname(fn))
    make_module(location: fn)
  rescue => e
    # remove *modul* methods from backtrace and reraise
    backtrace = e.backtrace.reject {|l| l.include?(__FILE__)}
    raise(e, e.message, backtrace)
  ensure
    FileUtils.chdir(pwd) if pwd
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
      module_facade(m)
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
      m.include(ModuleFacadeMethods)
      m.metaclass.include(ModuleFacadeMetaclassMethods)
      m.__export_default_block = export_default_block
    end
  end

  # Loads a source file or a block into the given module
  # @param m [Module] module
  # @param fn [String] source file path
  # @param block [Proc] module block (for namespaces)
  # @return [void]
  def self.load_module_code(m, info, &block)
    if block
      container = m.__module_info[:top_level_module]
      container_constants = container.constants
      m.module_eval(&block)
      diff_constants = container.constants - container_constants
      move_top_level_constants(container, m, diff_constants)
    else
      fn = info[:location]
      m.module_eval(IO.read(fn), fn)
    end
  end

  # Moves constants from one module to another
  # @param source [Module] source module
  # @param target [Module] target module
  # @param constants [Array] array of constant names
  def self.move_top_level_constants(source, target, constants)
    constants.each do |s|
      target.const_set(s, source.const_get(s))
      source.send(:remove_const, s)
    end
  end

  # Encapsulates a module by "wrapping" it in a facade class
  # @param m [Module] "raw" module
  # @return [Class] module facade
  def self.module_facade(m)
    Class.new(self).tap do |facade|
      module_info = m.__module_info
      facade.extend(m)
      facade.__module_info = module_info
      facade.__set_exported_symbols(m, m.__exported_symbols)
      set_namespace_symbol(facade, module_info[:module], module_info[:name])
    end
  end

  # Defines the given namespace on the given module using the given name
  # If the name starts with an upper-case letter, the namespace is defined as a
  # constant. Otherwise it is defined as a method.
  # @param namespace [Class] namespace
  # @param container [Module] containing module
  # @param name [String] symbol name
  # @return [void]
  def self.set_namespace_symbol(namespace, container, name)
    return unless container && name
    container = Object if container.class == Object
    if name =~ /^[A-Z]/
      container.const_set(name, namespace)
    else
      container.define_method(name) {namespace}
    end
  end

  # Returns the top level module for the given context
  # The top level module is where constants (and classes) are declared. We keep
  # track of the top level module in order to be able to move constants to
  # their proper place when using namespaces.
  # @param context [Module, Object] context calling `namespace'
  # @return [Module] top level module for constant declaration
  def self.top_level_module(context)
    context.respond_to?(:__module_info) &&
      context.__module_info[:top_level_module] ||
      (context.is_a?(Module) ? context : context.metaclass)
  end

  # Module façade methods
  module ModuleFacadeMethods
    # Responds to missing constants by checking metaclass
    # If the given constant is defined on the metaclass, the same constant is
    # defined on self and its value is returned. This is essential to
    # supporting constants in modules.
    # @param name [Symbol] constant name
    # @return [any] constant value
    def const_missing(name)
      if metaclass.const_defined?(name)
        unless @__exported_symbols.include?(name)
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
      m.instance_methods(false).each do |m|
        metaclass.send(:private, m) unless symbols.include?(m)
      end
    end

    # Returns a text representation of the module for inspection
    # @return [String] module string representation
    def inspect
      module_name = name || 'ModuleFacade'
      if __module_info[:location]
        "#{module_name}:#{__module_info[:location]}"
      else
        "#{module_name}"
      end
    end
  end

  # Module façade metaclass methods
  module ModuleFacadeMetaclassMethods
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

