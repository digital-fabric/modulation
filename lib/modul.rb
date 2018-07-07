# Shamelessly stolen from the metaid gem
class Object
  def metaclass; class << self; self; end; end
end

module ConstMissingModule
  def const_missing(m)
    if metaclass.const_defined?(m)
      v = metaclass.const_get(m)
      const_set(m, v)
      v
    else
      super
    end
  end
end

class ImportedModule
  @@imported_modules = {}

  def self.import(fn)
    fn << '.rb' if File.file?("#{fn}.rb")
    fn = File.expand_path(fn)
    @@imported_modules[fn] ||= Module.new.tap do |m|
      m.include(ConstMissingModule)
      m.module_eval {define_method(:module_path) {fn}}
      m.module_eval(IO.read(fn))
    end
  end

  class << self
    def inspect
      "#<#{ImportedModule} #{module_path}>"
    end
  end
end

module Kernel
  def import(fn)
    m = ImportedModule.import(fn)

    o = Class.new(ImportedModule)
    o.extend(m)
  end
end