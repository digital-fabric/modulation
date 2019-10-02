# frozen_string_literal: true

require_relative './export_from_receiver'

module Modulation
  # Functionality related to symbol export
  module Exports
    class << self
      # Performs the exporting of symbols after the module has loaded
      def perform_exports(mod)
        directives = mod.__export_directives
        exported_symbols = directives.inject [] do |exported, directive|
          symbols = export_directive mod, directive
          exported + symbols
        end
        set_exported_symbols mod, exported_symbols
      end

      def export_directive(mod, directive)
        send directive[:method], mod, *directive[:args]
      rescue NameError => e
        Modulation.raise_error e, directive[:export_caller]
      end

      def export(mod, *symbols)
        case symbols.first
        when Hash
          symbols = export_hash(mod, symbols.first)
        when Array
          symbols = symbols.first
        end

        validate_exported_symbols(mod, symbols)
        symbols
      end

      def export_from_receiver(mod, name)
        if name !~ Modulation::RE_CONST
          raise 'export_from_receiver expects a const reference'
        end

        ExportFromReceiver.from_const(mod, name)
      end

      def validate_exported_symbols(mod, symbols)
        defined_methods = mod.singleton_class.instance_methods(true)
        defined_constants = mod.singleton_class.constants(false)

        symbols.each do |sym|
          if sym =~ Modulation::RE_CONST
            validate_exported_symbol(sym, defined_constants, :const)
          else
            validate_exported_symbol(sym, defined_methods, :method)
          end
        end
      end

      def validate_exported_symbol(sym, list, kind)
        return if list.include? sym

        raise_exported_symbol_not_found_error(sym, kind)
      end

      # @return [Array] array of exported symbols
      def export_hash(mod, hash)
        singleton = mod.singleton_class
        hash.each { |k, v| export_hash_entry(singleton, k, v) }
        hash.keys
      end

      def export_hash_entry(singleton, key, value)
        symbol_value = value.is_a?(Symbol)
        const_value = value =~ Modulation::RE_CONST
        if value && const_value && singleton.const_defined?(value)
          value = singleton.const_get(value)
        end

        generate_exported_hash_entry(singleton, key, value, symbol_value)
      end

      def generate_exported_hash_entry(singleton, key, value, symbol_value)
        const_key = key =~ Modulation::RE_CONST
        if const_key
          singleton.const_set(key, value)
        elsif symbol_value && singleton.method_defined?(value)
          singleton.alias_method(key, value)
        else
          value_proc = value.is_a?(Proc) ? value : proc { value }
          singleton.send(:define_method, key, &value_proc)
        end
      end

      # Marks all non-exported methods as private, exposes exported constants
      # @param mod [Module] module with exported symbols
      # @param symbols [Array] array of exported symbols
      # @return [void]
      def set_exported_symbols(mod, symbols)
        mod.__module_info[:exported_symbols] = symbols
        singleton = mod.singleton_class

        privatize_non_exported_methods(singleton, symbols)
        expose_exported_constants(mod, singleton, symbols)
      end

      # Sets all non-exported methods as private for given module
      # @param singleton [Class] sinleton for module
      # @param symbols [Array] array of exported symbols
      # @return [void]
      def privatize_non_exported_methods(singleton, symbols)
        singleton.instance_methods(false).each do |sym|
          next if symbols.include?(sym)

          singleton.send(:private, sym)
        end
      end

      # Copies exported constants from singleton to module
      # @param mod [Module] module with exported symbols
      # @param singleton [Class] sinleton for module
      # @param symbols [Array] array of exported symbols
      # @return [void]
      def expose_exported_constants(mod, singleton, symbols)
        defined_constants = singleton.constants(false)
        process_module_constants(mod, singleton, symbols, defined_constants)
      end

      def process_module_constants(mod, singleton, symbols, defined_constants)
        private_constants = mod.__module_info[:private_constants] = []
        defined_constants.each do |sym|
          if symbols.include?(sym)
            mod.const_set(sym, singleton.const_get(sym))
          else
            private_constants << sym unless sym == :MODULE
          end
        end
      end

      NOT_FOUND_MSG = '%s %s not found in module'

      def raise_exported_symbol_not_found_error(sym, kind)
        msg = format(
          NOT_FOUND_MSG, kind == :method ? 'Method' : 'Constant', sym
        )
        raise NameError, msg
      end
    end
  end
end
