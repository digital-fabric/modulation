# frozen_string_literal: true

require 'modulation'

module Modulation
  class CLI
    def initialize(argv)
      @argv = argv

      process
    end

    def process
      cmd = ARGV.shift
      if respond_to? cmd.to_sym
        send cmd
      else
        ARGV.unshift cmd
        run
      end
    end

    def run
      @argv.each { |arg| run_file arg }
    rescue StandardError => e
      cleanup_backtrace(e)
      raise e
    end
    
    def run_file(arg)
      fn, method = filename_and_method_from_arg(arg)
      mod = import(File.expand_path(fn))
      mod.send(method) if method
    end
    
    FILENAME_AND_METHOD_RE = /^([^\:]+)\:(.+)$/.freeze
    
    def filename_and_method_from_arg(arg)
      if arg =~ FILENAME_AND_METHOD_RE
        match = Regexp.last_match
        [match[1], match[2].to_sym]
      else
        [arg, :main]
      end
    end
    
    BACKTRACE_RE = /^(#{Modulation::DIR})|(bin\/mdl)/.freeze
    
    def cleanup_backtrace(error)
      backtrace = error.backtrace.reject { |l| l =~ BACKTRACE_RE }
      error.set_backtrace(backtrace)
    end
    
    def collect_deps(path, array)
      if File.directory?(path)
        Dir["#{path}/**/*.rb"].each { |fn| collect_deps(fn, array) }
      else
        array << File.expand_path(path)
        mod = import(File.expand_path(path))
        if mod.respond_to?(:__traverse_dependencies)
          mod.__traverse_dependencies { |m| array << m.__module_info[:location] }
        end
      end
    end
    
    def deps
      paths = []
      @argv.each { |arg| collect_deps(arg, paths) }
      puts(*paths)
    end
    
    def pack
      require 'modulation/packer'
      STDOUT << Modulation::Packer.pack(@argv, hide_filenames: true)
    end
    
    def version
      puts "Modulation version #{Modulation::VERSION}"
    end
  end
end
