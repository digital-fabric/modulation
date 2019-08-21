# frozen_string_literal: true

require_relative '../modulation'
require 'zlib'

module Modulation
  # Implements packing functionality
  module Packer
    BOOTSTRAP = <<~SRC.encode('ASCII-8BIT').chomp
      # encoding: ASCII-8BIT
      require 'bundler/setup'
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
      dictionary, data = compute_pack_data(deps)
      generate_bootstrap(dictionary, data, entry_point_filename)
    end

    def self.collect_dependencies(paths)
      paths.each_with_object([]) do |fn, deps|
        mod = import(File.expand_path(fn))
        deps << File.expand_path(fn)
        mod.__traverse_dependencies { |m| deps << m.__module_info[:location] }
      end
    end

    def self.compute_pack_data(deps)
      last_offset = 0
      data = (+'').encode('ASCII-8BIT')
      dictionary = deps.each_with_object({}) do |path, dict|
        # warn "Processing #{path}"
        last_offset = add_packed_module(path, last_offset, dict, data)
      end
      [dictionary, data]
    end

    def self.add_packed_module(path, offset, dictionary, data)
      zipped = Zlib::Deflate.deflate(IO.read(path))
      length = zipped.bytesize
      dictionary[path] = [offset, length]
      data << zipped
      offset + length
    end

    def self.generate_bootstrap(dictionary, data, entry_point)
      format(BOOTSTRAP, dictionary: dictionary.inspect,
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
