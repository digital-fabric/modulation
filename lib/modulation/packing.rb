# frozen_string_literal: true

require_relative '../modulation'
require 'zlib'
require 'digest/md5'

module Modulation
  # Implements packing functionality
  module Packing
    BOOTSTRAP = <<~SRC.encode('ASCII-8BIT')
      # encoding: ASCII-8BIT
      require 'modulation'
      require 'zlib'

      b = Modulation::Builder
      z = Zlib::Inflate
      b::C = {%<module_dictionary>s}

      class << b
        alias_method :orig_make, :make

        def make(info)
          (pr = Modulation::Builder::C.delete(info[:location])) ? pr.call : orig_make(info)
        end
      end

      import(%<entry_point>s).send(:main)
    SRC

    MAKE_CODE = <<~SRC
      proc { b.orig_make(location: %<location>s, source: %<source>s) }
    SRC

    UNZIP_CODE = 'z.inflate(%<data>s)'

    # MAKE_CODE = <<~SRC
    #   Modulation::Builder.orig_make(location: %s, source: %s)
    # SRC

    # UNCAN_CODE = <<~SRC
    #   proc { RubyVM::InstructionSequence.load_from_binary(
    #     Zlib::Inflate.inflate(%s)).eval
    #   }
    # SRC

    def self.pack(paths, _options = {})
      paths = [paths] unless paths.is_a?(Array)

      entry_point_filename = nil
      dictionary = paths.each_with_object({}) do |path, dict|
        warn "Processing #{path}"
        source = IO.read(path)
        entry_point_filename ||= path
        dict[path] = pack_module(path, source)
      end

      generate_bootstrap(dictionary, entry_point_filename)
    end

    def self.pack_module(path, source)
      # code = (MAKE_CODE % [fn.inspect, module_source.inspect])
      # seq = RubyVM::InstructionSequence.compile(code, options)
      # canned = Zlib::Deflate.deflate(seq.to_binary)
      # dict[fn] = UNCAN_CODE % canned.inspect

      zipped = Zlib::Deflate.deflate(source)
      code = format(UNZIP_CODE, data: zipped.inspect)
      format(MAKE_CODE, location: path.inspect, source: code)
    end

    def self.generate_bootstrap(module_dictionary, entry_point)
      format(
        BOOTSTRAP,
        module_dictionary: format_module_dictionary(module_dictionary),
        entry_point: entry_point.inspect
      ).chomp.gsub(/^\s+/, '').gsub(/\n+/, "\n")
    end

    def self.format_module_dictionary(module_dictionary)
      module_dictionary.map do |fn, code|
        format(
          '%<filename>s => %<code>s',
          filename: fn.inspect,
          code: code
        ).chomp
      end.join(',')
    end
  end
end
