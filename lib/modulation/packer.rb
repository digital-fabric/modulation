# frozen_string_literal: true

require_relative '../modulation'
require_relative '../modulation/version'
require 'zlib'

module Modulation
  # Implements packing functionality
  module Packer
    BOOTSTRAP_CODE = <<~SRC.encode('ASCII-8BIT').chomp
      # encoding: ASCII-8BIT
      require 'bundler/inline'

      gemfile do
        source 'https://rubygems.org'
        gem 'modulation', '~> %<modulation_version>s'
      end

      require 'modulation/packer'
      Modulation::Bootstrap.setup(DATA, %<dictionary>s)
      import(%<entry_point>s).send(:main)
      __END__
      %<data>s
    SRC

    def self.pack(paths, _options = {})
      paths = [paths] unless paths.is_a?(Array)
      deps = collect_dependencies(paths)
      entry_point_filename = File.expand_path(paths.first)
      dictionary, data = generate_packed_data(deps)
      generate_bootstrap(dictionary, data, entry_point_filename)
    end

    def self.collect_dependencies(paths)
      paths.each_with_object([]) do |fn, deps|
        mod = import(File.expand_path(fn))
        deps << File.expand_path(fn)
        mod.__traverse_dependencies { |m| deps << m.__module_info[:location] }
      end
    end

    def self.generate_packed_data(deps)
      files = deps.each_with_object({}) do |path, dict|
        dict[path] = IO.read(path)
      end
      # files[INLINE_GEMFILE_PATH] = generate_gemfile
      pack_files(files)
    end

    def self.pack_files(files)
      data = (+'').encode('ASCII-8BIT')
      last_offset = 0
      dictionary = files.each_with_object({}) do |(path, content), dict|
        zipped = Zlib::Deflate.deflate(content)
        size = zipped.bytesize
        
        data << zipped
        dict[path] = [last_offset, size]
        last_offset += size
      end
      [dictionary, data]
    end

    # def self.generate_gemfile
    #   format(INLINE_GEMFILE_CODE)
    # end

    def self.generate_bootstrap(dictionary, data, entry_point)
      format(BOOTSTRAP_CODE, modulation_version: Modulation::VERSION,
                             dictionary: dictionary.inspect,
                             entry_point: entry_point.inspect,
                             data: data)
    end
  end

  # Packed app bootstrapping code
  module Bootstrap
    def self.setup(data, dictionary)
      patch_builder
      @data = data
      @data_offset = data.pos
      @dictionary = dictionary
    end

    def self.patch_builder
      class << Modulation::Builder
        alias_method :orig_make, :make
        def make(info)
          if Modulation::Bootstrap.find(info[:location])
            info[:source] = Modulation::Bootstrap.read(info[:location])
          end
          orig_make(info)
        end
      end
    end

    def self.find(path)
      @dictionary[path]
    end

    def self.read(path)
      (offset, length) = @dictionary[path]
      @data.seek(@data_offset + offset)
      Zlib::Inflate.inflate(@data.read(length))
    end
  end
end
