# frozen_string_literal: true

# Implements main Modulation functionality
module Modulation
  require_relative './paths'
  require_relative './builder'
  require_relative './module_mixin'

  extend self

  # @return [Hash] hash of loaded modules, mapping absolute paths to modules
  attr_reader :loaded_modules

  # @return [Module] currently loaded top-level module
  attr_accessor :top_level_module

  # Resets the loaded modules hash
  def reset!
    @loaded_modules = {}
  end

  # Show full backtrace for errors occuring while loading a module. Normally
  # Modulation will remove stack frames occurring inside the modulation.rb code
  # in order to make backtraces more readable when debugging.
  def full_backtrace!
    @full_backtrace = true
  end

  # Imports a module from a file
  # If the module is already loaded, returns the loaded module.
  # @param path [String] unqualified file name
  # @param caller_location [String] caller location
  # @return [Module] loaded module object
  def import(path, caller_location = caller(1..1).first)
    path = Paths.absolute_path(path, caller_location)
    @loaded_modules[path] || create_module_from_file(path)
  end

  # Creates a new module from a source file
  # @param path [String] source file name
  # @return [Module] module
  def create_module_from_file(path)
    Builder.make(location: path)
  rescue StandardError => e
    @full_backtrace ? raise : raise_with_clean_backtrace(e)
  end

  # (Re-)raises an error, filtering its backtrace to remove stack frames
  # occuring in Modulation code
  # @param error [Error] raised error
  # @return [void]
  def raise_with_clean_backtrace(error)
    backtrace = error.backtrace.reject { |l| l.include?(__FILE__) }
    raise(error, error.message, backtrace)
  end

  # Reloads the given module from its source file
  # @param mod [Module, String] module to reload
  # @return [Module] module
  def reload(mod)
    if mod.is_a?(String)
      path = mod
      mod = @loaded_modules[File.expand_path(mod)]
      raise "No module loaded from #{path}" unless mod
    end

    Builder.cleanup_module(mod)
    Builder.reload_module_code(mod)

    mod.tap { Builder.set_exported_symbols(mod, mod.__exported_symbols, true) }
  end

  # Maps the given path to the given mock module, restoring the previously 
  # loaded module (if any) after calling the given block
  # @param path [String] module path
  # @param mod [Module] module
  # @param caller_location [String] caller location
  # @return [void]
  def mock(path, mod, caller_location = caller(1..1).first)
    path = Paths.absolute_path(path, caller_location)
    old_module = @loaded_modules[path]
    @loaded_modules[path] = mod
    yield if block_given?
  ensure
    @loaded_modules[path] = old_module if block_given?
  end
end

Modulation.reset!
