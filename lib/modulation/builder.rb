# frozen_string_literal: true

module Modulation
  # Implements creation of module instances
  module Builder
    extend self

    # Loads a module from file or block, wrapping it in a module facade
    # @param info [Hash] module info
    # @param block [Proc] module block
    # @return [Class] module facade
    def make(info, &block)
      default = nil
      mod = create(info) { |default_info| default = default_info }
      Modulation.loaded_modules[info[:location]] = mod
      load_module_code(mod, info, &block)
      if default
        set_module_default_value(default[:value], info, mod, default[:caller])
      else
        set_exported_symbols(mod, mod.__exported_symbols, true)
        mod
      end
    end

    # Initializes a new module ready to evaluate a file module
    # @note The given block is used to pass the value given to `export_default`
    # @param info [Hash] module info
    # @return [Module] new module
    def create(info, &export_default_block)
      Module.new.tap do |mod|
        mod.extend(mod)
        mod.extend(ModuleMixin)
        mod.__module_info = info
        mod.__export_default_block = export_default_block
        mod.const_set(:MODULE, mod)
      end
    end

    # Loads a source file or a block into the given module
    # @param mod [Module] module
    # @param info [Hash] module info
    # @return [void]
    def load_module_code(mod, info, &block)
      old_top_level_module = Modulation.top_level_module
      Modulation.top_level_module = mod
      if block
        mod.module_eval(&block)
      else
        path = info[:location]
        mod.module_eval(IO.read(path), path)
      end
    ensure
      Modulation.top_level_module = old_top_level_module
    end

    # Marks all non-exported methods as private
    # @param mod [Module] module with exported symbols
    # @param symbols [Array] array of exported symbols
    # @param perform_deferred_exports [Boolean] perform deferred export flag
    # @return [void]
    def set_exported_symbols(mod, symbols, perform_deferred_exports = false)
      mod.__perform_deferred_namespace_exports if perform_deferred_exports

      mod.instance_methods.each do |sym|
        next if symbols.include?(sym)
        mod.send(:private, sym)
      end
      mod.constants.each do |sym|
        next if sym == :MODULE || symbols.include?(sym)
        mod.send(:private_constant, sym)
      end
    end

    # Returns exported value for a default export
    # If the given value is a symbol, returns the value of the corresponding
    # constant.
    # @param value [any] export_default value
    # @param mod [Module] module
    # @return [any] exported value
    def transform_export_default_value(value, mod)
      value.is_a?(Symbol) ? mod.const_get(value) : value
    rescue NameError
      value
    end

    # Loads code for a module being reloaded, turning warnings off in order to
    # not generate warnings upon re-assignment of constants
    def reload_module_code(mod)
      orig_verbose = $VERBOSE
      $VERBOSE = nil
      load_module_code(mod, mod.__module_info)
    ensure
      $VERBOSE = orig_verbose
    end

    # Removes methods and constants from module
    # @param mod [Module] module
    # @return [void]
    def cleanup_module(mod)
      mod.constants(false).each { |c| mod.send(:remove_const, c) }
      mod.methods(false).each { |sym| mod.send(:undef_method, sym) }

      private_methods = mod.private_methods(false) -
                        Module.private_instance_methods(false)
      private_methods.each { |sym| mod.send(:undef_method, sym) }

      mod.__exported_symbols.clear
    end

    # Error message to be displayed when trying to set a singleton value as
    # default export
    DEFAULT_VALUE_ERROR_MSG =
      'Default export cannot be boolean, numeric, or symbol'

    # Sets the default value for a module using export_default
    # @param value [any] default value
    # @param info [Hash] module info
    # @param mod [Module] module
    # @return [any] default value
    def set_module_default_value(value, info, mod, caller)
      value = transform_export_default_value(value, mod)
      case value
      when nil, true, false, Numeric, Symbol
        raise(TypeError, DEFAULT_VALUE_ERROR_MSG, caller)
      end
      set_reload_info(value, mod.__module_info)
      Modulation.loaded_modules[info[:location]] = value
    end

    # Adds methods for module_info and reloading to a value exported as default
    # @param value [any] export_default value
    # @param info [Hash] module info
    # @return [void]
    def set_reload_info(value, info)
      value.define_singleton_method(:__module_info) { info }
      value.define_singleton_method(:__reload!) do
        Modulation::Builder.make(info)
      end
    end
  end
end
