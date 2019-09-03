# frozen_string_literal: true

require_relative('exports')
require_relative('export_default')

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
        mod.instance_eval(info[:source] || IO.read(path), path)
      end

      def finalize_module_exports(info, mod)
        if (default = mod.__export_default_info)
          ExportDefault.set_module_default_value(
            default[:value], info, mod, default[:caller]
          )
        else
          Exports.perform_exports(mod)
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
        Exports.perform_exports(mod)
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

        mod.__before_reload
      end

      # Adds all or part of a module's methods to a target object
      # If no symbols are given, all methods are added
      # @param mod [Module] imported module
      # @param target [Object] object to add methods to
      # @param symbols [Array<Symbol>] list of methods to add
      # @return [void]
      def add_module_methods(mod, target, *symbols)
        methods = mod.singleton_class.instance_methods(false)
        unless symbols.empty?
          symbols.select! { |s| s =~ /^[a-z]/ }
          methods = filter_exported_symbols(methods, symbols)
        end
        methods.each do |sym|
          target.send(:define_method, sym, &mod.method(sym))
        end
      end

      # Adds all or part of a module's constants to a target object
      # If no symbols are given, all constants are added
      # @param mod [Module] imported module
      # @param target [Object] object to add constants to
      # @param symbols [Array<Symbol>] list of constants to add
      # @return [void]
      def add_module_constants(mod, target, *symbols)
        exported = mod.__module_info[:exported_symbols]
        unless symbols.empty?
          symbols.select! { |s| s =~ Modulation::RE_CONST }
          exported = filter_exported_symbols(exported, symbols)
        end
        mod.singleton_class.constants(false).each do |sym|
          next unless exported.include?(sym)

          target.const_set(sym, mod.singleton_class.const_get(sym))
        end
      end

      def filter_exported_symbols(exported, requested)
        not_exported = requested - exported
        unless not_exported.empty?
          raise NameError, "symbol #{not_exported.first.inspect} not exported"
        end

        exported & requested
      end

      # Defines a const_missing method used for auto-importing on a given object
      # @param receiver [Object] object to receive the const_missing method call
      # @param auto_import_hash [Hash] a hash mapping constant names to a source
      #   file and a caller location
      # @return [void]
      def define_auto_import_const_missing_method(receiver, auto_import_hash)
        receiver.singleton_class.define_method(:const_missing) do |sym|
          (path, caller_location) = auto_import_hash[sym]
          path ? const_set(sym, import(path, caller_location)) : super(sym)
        end
      end
    end
  end
end
