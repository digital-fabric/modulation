# frozen_string_literal: true

require_relative('exports')
require_relative('default_export')

module Modulation
  # Implements creation of module instances
  module Builder
    class << self
      # Loads a module from file or block, wrapping it in a module facade
      # @param info [Hash] module info
      # @param block [Proc] module block
      # @return [Class] module facade
      def make(info)
        # create module object
        mod = create(info)
        track_module_dependencies(mod) do
          # add module to loaded modules hash
          Modulation.loaded_modules[info[:location]] = mod

          load_module_code(mod, info)
          finalize_module_exports(info, mod)
        end
      end

      # Initializes a new module ready to evaluate a file module
      # @note The given block is used to pass the value given to
      # `export_default`
      # @param info [Hash] module info
      # @return [Module] new module
      def create(info)
        Module.new.tap do |mod|
          mod.extend(ModuleMixin)
          mod.__module_info = info
          mod.singleton_class.const_set(:MODULE, mod)
        end
      end

      def track_module_dependencies(mod)
        prev_module = Thread.current[:__current_module]
        Thread.current[:__current_module] = mod

        if prev_module
          prev_module.__add_dependency(mod)
          mod.__add_dependent_module(prev_module)
        end
        yield
      ensure
        Thread.current[:__current_module] = prev_module
      end

      # Loads a source file or a block into the given module
      # @param mod [Module] module
      # @param info [Hash] module info
      # @return [void]
      def load_module_code(mod, info)
        path = info[:location]
        mod.instance_eval(IO.read(path), path)
        mod.__post_load
      end

      def finalize_module_exports(info, mod)
        if (default = mod.__export_default_info)
          DefaultExport.set_module_default_value(
            default[:value], info, mod, default[:caller]
          )
        else
          Exports.set_exported_symbols(mod, mod.__exported_symbols)
          mod
        end
      end

      # Loads code for a module being reloaded, turning warnings off in order to
      # not generate warnings upon re-assignment of constants
      def reload_module_code(mod)
        orig_verbose = $VERBOSE
        $VERBOSE = nil
        prev_module = Thread.current[:__current_module]
        Thread.current[:__current_module] = mod

        cleanup_module(mod)
        load_module_code(mod, mod.__module_info)
        Exports.set_exported_symbols(mod, mod.__exported_symbols)
      ensure
        Thread.current[:__current_module] = prev_module
        $VERBOSE = orig_verbose
      end

      # Removes methods and constants from module
      # @param mod [Module] module
      # @return [void]
      def cleanup_module(mod)
        mod.constants(false).each { |c| mod.send(:remove_const, c) }
        singleton = mod.singleton_class
        undef_method = singleton.method(:undef_method)

        singleton.instance_methods(false).each(&undef_method)
        singleton.private_instance_methods(false).each(&undef_method)

        mod.__exported_symbols.clear
        mod.__reset_dependencies
      end
    end
  end
end
