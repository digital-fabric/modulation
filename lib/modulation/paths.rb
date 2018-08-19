# frozen_string_literal: true

module Modulation
  # Implements methods for expanding relative or incomplete module file names
  module Paths
    extend self

    # Regexp for extracting filename from caller reference
    CALLER_FILE_REGEXP = /^([^\:]+)\:/

    # Resolves the absolute path to the provided reference. If the file is not
    # found, will try to resolve to a gem
    # @param path [String] unqualified file name
    # @param caller_location [String] caller location
    # @return [String] absolute file name
    def absolute_path(path, caller_location = caller(1..1).first)
      orig_path = path
      caller_file = caller_location[CALLER_FILE_REGEXP, 1]
      raise 'Could not expand path' unless caller_file

      path = File.expand_path(path, File.dirname(caller_file))
      check_path(path) || lookup_gem(orig_path) ||
        (raise "Module not found: #{path}")
    end

    # Checks that the given path references an existing file, adding the .rb
    # extension if needed
    # @param path [String] absolute file path (with/without .rb extension)
    # @return [String, nil] path of file or nil if not found
    def check_path(path)
      if File.file?("#{path}.rb")
        path + '.rb'
      elsif File.file?(path)
        path
      end
    end

    # Resolves the provided file name into a gem. If no gem is found, returns
    # nil
    # @param name [String] gem name
    # @return [String] absolute path to gem main source file
    def lookup_gem(name)
      spec = Gem::Specification.find_by_name(name)
      unless spec.dependencies.map(&:name).include?('modulation')
        raise NameError, 'Cannot import gem not based on modulation'
      end
      path = File.join(spec.full_require_paths, "#{name}.rb")
      File.file?(path) ? path : nil
    rescue Gem::MissingSpecError
      nil
    end
  end
end
