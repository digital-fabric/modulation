# frozen_string_literal: true

# Implements main Modulation functionality
module Modulation
  require_relative './paths'
  require_relative './builder'
  require_relative './module_mixin'

  RE_CONST = /^[A-Z]/.freeze

  class << self
    CALLER_RANGE = (1..1).freeze

    # @return [Hash] hash of loaded modules, mapping absolute paths to modules
    attr_reader :loaded_modules

    # Resets the loaded modules hash
    def reset!
      @loaded_modules = {}
    end

    # Show full backtrace for errors occuring while loading a module. Normally
    # Modulation will remove stack frames occurring inside the modulation.rb
    # code in order to make backtraces more readable when debugging.
    def full_backtrace!
      @full_backtrace = true
    end

    GEM_REQUIRE_ERROR_MESSAGE = <<~MSG
      Can't import from a gem that doesn't depend on Modulation. Please use `require` instead of `import`.
    MSG

    # Imports a module from a file
    # If the module is already loaded, returns the loaded module.
    # @param path [String] unqualified file name
    # @param caller_location [String] caller location
    # @return [Module] loaded module object
    def import(path, caller_location = caller(CALLER_RANGE).first)
      abs_path = Paths.process(path, caller_location)

      case abs_path
      when String
        @loaded_modules[abs_path] || create_module_from_file(abs_path, caller)
      when :require_gem
        raise_error(LoadError.new(GEM_REQUIRE_ERROR_MESSAGE), caller)
      else
        raise_error(LoadError.new("Module not found: #{path}"), caller)
      end
    end

    # Imports all source files in given directory
    # @ param path [String] relative directory path
    # @param caller_location [String] caller location
    # @return [Array] array of module objects
    def import_all(path, caller_location = caller(CALLER_RANGE).first)
      abs_path = Paths.absolute_dir_path(path, caller_location)
      Dir["#{abs_path}/**/*.rb"].map do |fn|
        @loaded_modules[fn] || create_module_from_file(fn, caller)
      end
    end

    # Imports all source files in given directory, returning a hash mapping
    # filenames to modules
    # @ param path [String] relative directory path
    # @ param options [Hash] options
    # @param caller_location [String] caller location
    # @return [Hash] hash mapping filenames to modules
    def import_map(path, options = {},
                   caller_location = caller(CALLER_RANGE).first)
      abs_path = Paths.absolute_dir_path(path, caller_location)
      use_symbols = options[:symbol_keys]
      Dir["#{abs_path}/*.rb"].each_with_object({}) do |fn, h|
        mod = @loaded_modules[fn] || create_module_from_file(fn, caller)
        name = File.basename(fn) =~ /^(.+)\.rb$/ && Regexp.last_match(1)
        h[use_symbols ? name.to_sym : name] = mod
      end
    end

    def auto_import_map(path, options = {},
                        caller_location = caller(CALLER_RANGE).first)
      abs_path = Paths.absolute_dir_path(path, caller_location)
      Hash.new do |h, k|
        fn = Paths.check_path(File.join(abs_path, k.to_s))
        h[k] = find_auto_import_module(fn, path, options)
      end
    end

    def find_auto_import_module(fn, path, options)
      return @loaded_modules[fn] || create_module_from_file(fn, caller) if fn
      return options[:not_found] if options.has_key?(:not_found)
      
      raise "Module not found #{path}"
    end

    # Creates a new module from a source file
    # @param path [String] source file name
    # @return [Module] module
    def create_module_from_file(path, import_caller)
      Builder.make(location: path, caller: import_caller)
    rescue StandardError => e
      raise_error(e)#, import_caller)
    end

    # (Re-)raises an error, potentially filtering its backtrace to remove stack
    # frames occuring in Modulation code
    # @param error [Error] raised error
    # @param caller [Array] error backtrace
    # @return [void]
    def raise_error(error, backtrace = nil)
      if backtrace
        unless @full_backtrace
          backtrace = backtrace.reject { |l| l =~ /^#{Modulation::DIR}/ }
        end
        error.set_backtrace(backtrace)
      end
      raise error
    end

    # Reloads the given module from its source file
    # @param mod [Module, String] module to reload
    # @return [Module] module
    def reload(mod)
      if mod.is_a?(String)
        path = mod
        mod = @loaded_modules[File.expand_path(mod)]
        raise "No module loaded from #{path}" unless mod
      end

      Builder.reload_module_code(mod)
      mod
    end

    # Maps the given path to the given mock module, restoring the previously
    # loaded module (if any) after calling the given block
    # @param path [String] module path
    # @param mod [Module] module
    # @param caller_location [String] caller location
    # @return [void]
    def mock(path, mod, caller_location = caller(CALLER_RANGE).first)
      path = Paths.absolute_path(path, caller_location)
      old_module = @loaded_modules[path]
      @loaded_modules[path] = mod
      yield if block_given?
    ensure
      @loaded_modules[path] = old_module if block_given?
    end

    def add_tags(tags)
      Paths.add_tags(tags, caller(CALLER_RANGE).first)
    end
  end
end

Modulation.reset!
