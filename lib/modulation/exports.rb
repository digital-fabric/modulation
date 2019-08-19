# frozen_string_literal: true

module Modulation
  # Export functionality
  module Exports
    class << self
      # Marks all non-exported methods as private
      # @param mod [Module] module with exported symbols
      # @param symbols [Array] array of exported symbols
      # @return [void]
      def set_exported_symbols(mod, symbols)
        mod.__module_info[:exported_symbols] = symbols
        singleton = mod.singleton_class

        privatize_non_exported_methods(mod, singleton, symbols)
        expose_exported_constants(mod, singleton, symbols)
      end

      # Sets all non-exported methods as private for given module
      # @param singleton [Class] sinleton for module
      # @param symbols [Array] array of exported symbols
      # @return [void]
      def privatize_non_exported_methods(mod, singleton, symbols)
        defined_methods = singleton.instance_methods(true)
        difference = symbols.select { |s| s =~ /^[a-z]/ } - defined_methods
        unless difference.empty?
          raise_exported_symbol_not_found_error(difference.first, mod, :method)
        end

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
        difference = symbols.select { |s| s =~ /^[A-Z]/ } - defined_constants
        unless difference.empty?
          raise_exported_symbol_not_found_error(difference.first, mod, :const)
        end
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
    end
  end
end
