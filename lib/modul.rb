require 'fileutils'

# Kernel extensions - modul's API
module Kernel
  # Returns an encapsulated imported module
  # @param fn [String] module file name
  # @return [EncapsulatedModule] encapsulated module
  def import(fn)
    Modul.import_module(fn)
  end

  # Creates a namespace sub-module and exposes to the outside world if a name
  # is given
  # @param name [String, nil] namespace name.
  # @param block [Proc] namespace block
  def namespace(name = nil, &block)
    Modul.make_module(&block).tap do |o|
      define_method(name) {o} if name
    end
  end
end

# Object extensions
class Object
  # Returns the objects metaclass
  #   (shamelessly stolen from the metaid gem)
  #
  # @return [Class] object's metaclass
  def metaclass; class << self; self; end; end
end

# Encapsulated module extensions
module EncapsulatedModuleExtensions
  # Checks if the given constant is defined on the metaclass, and if so defines
  # the constant on self and returns its value. This is essential to supporting
  # constants in modules
  #
  # @param name [Symbol] constant name
  # @return [any] constant value
  def const_missing(name)
    if metaclass.const_defined?(name)
      metaclass.const_get(name).tap {|value| const_set(name, value)}
    else
      super
    end
  end
end

class Modul
  @@loaded_modules = {}

  # Loads a module from a file.
  #
  # @param fn [String] module file name (with or without extension)
  # @return [EncapsulatedModule] loaded module object
  def self.import_module(fn)
    if File.file?("#{fn}.rb")
      fn << '.rb'
    else
      raise "Module not found: #{fn}" unless File.file?(fn)
    end
    fn = File.expand_path(fn)
    @@loaded_modules[fn] ||= load_module(fn)
  end

  def self.load_module(fn)
    pwd = FileUtils.pwd
    FileUtils.chdir(File.dirname(fn))
    make_module(fn)
  rescue => e
    # remove *modul* methods from backtrace and reraise
    backtrace = e.backtrace.reject {|l| l.include?(__FILE__)}
    raise(e, e.message, backtrace)
  ensure
    FileUtils.chdir(pwd) if pwd
  end

  # Makes an encapsulated module from a filename or a block
  # @param fn [String] module filename
  # @param block [Proc] module block
  # @return [Module] module object
  def self.make_module(fn = nil, &block)
    default_export = nil
    m = initialize_module {|v| default_export = v}
    load_module_code(m, fn, &block)
    default_export || encapsulate_module(m)
  end

  # Initializes a new module ready to evaluate a file module
  # The given block is used to pass the value given to `default_export`
  # 
  # @return [Module] new module
  def self.initialize_module(&default_export_block)
    Module.new.tap do |m|
      m.include(EncapsulatedModuleExtensions)
      m.metaclass.define_method(:default_export) do |v|
        default_export_block.call(v)
      end
    end
  end

  # Loads a source file or a block into the given module
  # @param m [Module] module
  # @param fn [String] source file path
  # @param &block [Proc] module block (for namespaces)
  # @return [void]
  def self.load_module_code(m, fn, &block)
    if fn
      m.module_eval {define_method(:module_path) {fn}}
      m.module_eval(IO.read(fn), fn)
    else
      m.module_eval(&block)
    end
  end

  # Encapsulates a module into an instance of EncapsulatedModule
  # @param m [Module] "raw" module
  # @return [EncapsulatedModule] encapsulated module
  def self.encapsulate_module(m)
    Class.new(EncapsulatedModule).tap {|o| o.extend(m)}
  end
end

# Encapsulates an imported module or a namespace
# functionality while also serving as a base class for actual imported module.
class EncapsulatedModule
  # Returns a text representation of the module for inspection
  # 
  # @return [String] module string representation
  def inspect
    if module_path
      "#<#{EncapsulatedModule}:#{module_path}>"
    else
      "#<#{EncapsulatedModule}>"
    end
  end
end