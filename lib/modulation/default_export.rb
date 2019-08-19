# frozen_string_literal: true

module Modulation
  # default export functionality
  module DefaultExport
    class << self
      # Returns exported value for a default export
      # If the given value is a symbol, returns the value of the corresponding
      # constant. If the symbol refers to a method, returns a proc enveloping
      # the method. Raises if symbol refers to non-existent constant or method.
      # @param value [any] export_default value
      # @param mod [Module] module
      # @return [any] exported value
      def transform_export_default_value(value, mod)
        return value unless value.is_a?(Symbol)

        case value
        when /^[A-Z]/
          get_module_constant(mod, value)
        else
          get_module_method(mod, value)
        end
      end

      def get_module_constant(mod, value)
        unless mod.singleton_class.constants(true).include?(value)
          raise_exported_symbol_not_found_error(value, mod, :const)
        end

        mod.singleton_class.const_get(value)
      end

      def get_module_method(mod, value)
        unless mod.singleton_class.instance_methods(true).include?(value)
          raise_exported_symbol_not_found_error(value, mod, :method)
        end

        proc { |*args, &block| mod.send(value, *args, &block) }
      end

      NOT_FOUND_MSG = '%s %s not found in module'

      def raise_exported_symbol_not_found_error(sym, mod, kind)
        msg = format(
          NOT_FOUND_MSG, kind == :method ? 'Method' : 'Constant', sym
        )
        error = NameError.new(msg)
        Modulation.raise_error(error, mod.__export_backtrace)
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

      # Adds methods for module_info and reloading to a value exported as
      # default
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
end
