# frozen_string_literal: true

module Modulation
  # Extension methods for loaded modules
  module ModuleMixin
    # read and write module information
    attr_accessor :__module_info

    # Adds given symbols to the exported_symbols array
    # @param symbols [Array] array of symbols
    # @return [void]
    def export(*symbols)
      case symbols.first
      when Hash
        symbols = __convert_export_hash(symbols.first)
      when Array
        symbols = symbols.first
      end

      self.__exported_symbols.concat(symbols)
      self.__export_backtrace = caller
    end

    def __convert_export_hash(hash)
      @__exported_hash = hash
      hash.keys
    end

    RE_CONST = /^[A-Z]/.freeze

    def __post_load
      if @__exported_hash
        singleton = singleton_class
        @__exported_hash.map do |k, v|
          symbol = v.is_a?(Symbol)
          if symbol && v =~ RE_CONST && singleton.const_defined?(v)
            v = singleton.const_get(v)
          end
          
          k =~ RE_CONST ? singleton.const_set(k, v) :
            symbol && singleton.method_defined?(v) ? singleton.alias_method(k, v) :
            v.is_a?(Proc) ? singleton.define_method(k, &v) :
            singleton.define_method(k) { v }

          k
        end
      end
    end

    # Sets a module's value, so when imported it will represent the given value,
    # instead of a module facade
    # @param value [Symbol, any] symbol or value
    # @return [void]
    def export_default(value)
      self.__export_backtrace = caller
      @__export_default_block&.call(value: value, caller: caller)
    end

    # Returns a text representation of the module for inspection
    # @return [String] module string representation
    def inspect
      module_name = name || 'Module'
      if __module_info[:location]
        "#{module_name}:#{__module_info[:location]}"
      else
        module_name
      end
    end

    # Sets export_default block, used for setting the returned module object to
    # a class or constant
    # @param block [Proc] default export block
    # @return [void]
    def __export_default_block=(block)
      @__export_default_block = block
    end

    # Reload module
    # @return [Module] module
    def __reload!
      Modulation.reload(self)
    end

    # Defers exporting of symbols for a namespace (nested module), to be
    # performed after the entire module has been loaded
    # @param namespace [Module] namespace module
    # @param symbols [Array] array of symbols
    # @return [void]
    def __defer_namespace_export(namespace, symbols)
      @__namespace_exports ||= Hash.new { |h, k| h[k] = [] }
      @__namespace_exports[namespace].concat(symbols)
    end

    # Performs exporting of symbols for all namespaces defined in the module,
    # marking unexported methods and constants as private
    # @return [void]
    def __perform_deferred_namespace_exports
      return unless @__namespace_exports

      @__namespace_exports.each do |m, symbols|
        Builder.set_exported_symbols(m, symbols)
      end
    end

    # Returns exported_symbols array
    # @return [Array] array of exported symbols
    def __exported_symbols
      @__exported_symbols ||= []
    end

    def __export_backtrace
      @__export_backtrace
    end

    def __export_backtrace=(o)
      @__export_backtrace = o
    end

    # Allow modules to use attr_accessor/reader/writer and include methods by
    # forwarding calls to singleton_class
    %i[attr_accessor attr_reader attr_writer include].each do |sym|
      define_method(sym) { |*args| singleton_class.send(sym, *args) }
    end

    # Exposes all private methods and private constants as public
    # @return [Module] self
    def __expose!
      singleton = singleton_class

      singleton.private_instance_methods.each do |sym|
        singleton.send(:public, sym)
      end
      
      __module_info[:private_constants].each do |sym|
        const_set(sym, singleton.const_get(sym))
      end

      self
    end
  end
end
