# frozen_string_literal: true

# Kernel extensions
module Kernel
  # Returns an encapsulated imported module.
  # @param path [String] module file name
  # @param caller_location [String] caller location
  # @return [Class] module facade
  def import(path, caller_location = caller(1..1).first)
    Modulation.import(path, caller_location)
  end
end

# Module extensions
class Module
  # Exports symbols from a namespace module declared inside an importable
  # module. Exporting the actual symbols is deferred until the entire code
  # has been loaded
  # @param symbols [Array] array of symbols
  # @return [void]
  def export(*symbols)
    unless Modulation.top_level_module
      raise NameError, "Can't export symbols outside of an imported module"
    end

    extend self
    Modulation.top_level_module.__defer_namespace_export(self, symbols)
  end

  # Extends the receiver with exported methods from the given file name
  # @param path [String] module filename
  # @return [void]
  def extend_from(path)
    mod = import(path, caller(1..1).first)
    mod.instance_methods(false).each do |sym|
      self.class.send(:define_method, sym, mod.method(sym).to_proc)
    end
  end

  # Includes exported methods from the given file name in the receiver
  # The module's methods will be available as instance methods
  # @param path [String] module filename
  # @return [void]
  def include_from(path)
    mod = import(path, caller(1..1).first)
    mod.instance_methods(false).each do |sym|
      send(:define_method, sym, mod.method(sym).to_proc)
    end
  end
end
