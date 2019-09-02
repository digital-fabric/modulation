# frozen_string_literal: true

module Modulation
  # Extension methods for loaded modules
  module ModuleMixin
    # read and write module information
    attr_accessor :__module_info
    attr_reader :__export_default_info

    def __before_reload
      @__module_info[:exported_symbols] = []
      @__export_directives = nil
      __reset_dependencies
    end

    def __export_directives
      @__export_directives || []
    end

    def __exported_symbols
      __module_info[:exported_symbols]
    end

    # Adds given symbols to the exported_symbols array
    # @param symbols [Array] array of symbols
    # @return [void]
    def export(*symbols)
      if @__export_default_info
        raise 'Cannot mix calls to export and export_default in same module'
      end

      @__export_directives ||= []

      @__export_directives << {
        method: :export,
        args: symbols,
        export_caller: caller
      }
    end

    # Sets a module's value, so when imported it will represent the given value,
    # instead of a module facade
    # @param value [Symbol, any] symbol or value
    # @return [void]
    def export_default(value)
      unless __export_directives.empty?
        raise 'Cannot mix calls to export and export_default in the same module'
      end

      @__export_default_info = { value: value, caller: caller }
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

    # Reload module
    # @return [Module] module
    def __reload!
      Modulation.reload(self)
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

    def __dependencies
      @__dependencies ||= []
    end

    def __add_dependency(mod)
      __dependencies << mod unless __dependencies.include?(mod)
    end

    def __traverse_dependencies(&block)
      __dependencies.each do |mod|
        block.call mod
        if mod.respond_to?(:__traverse_dependencies)
          mod.__traverse_dependencies(&block)
        end
      end
    end

    def __dependent_modules
      @__dependent_modules ||= []
    end

    def __add_dependent_module(mod)
      __dependent_modules << mod unless __dependent_modules.include?(mod)
    end

    def __reset_dependencies
      return unless @__dependencies

      @__dependencies.each do |mod|
        next unless mod.respond_to?(:__dependent_modules)

        mod.__dependent_modules.delete(self)
      end
      @__dependencies.clear
    end
  end
end
