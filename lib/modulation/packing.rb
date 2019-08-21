# frozen_string_literal: true

require_relative '../modulation'
require 'zlib'
require 'digest/md5'

# Implements main Modulation functionality
module Modulation
  module Packing
    BOOTSTRAP = <<~EOF.encode('ASCII-8BIT')
      # encoding: ASCII-8BIT
      require 'modulation'
      require 'zlib'

      b = Modulation::Builder
      z = Zlib::Inflate
      b::C = {%s}

      class << b
        alias_method :orig_make, :make

        def make(info)
          (pr = Modulation::Builder::C.delete(info[:location])) ? pr.call : orig_make(info)
        end
      end

      import(%s).send(:main)
    EOF

    UNZIP_CODE =<<~EOF
      proc { b.orig_make(location: %s, source: %s) }
    EOF

    # MAKE_CODE = <<~EOF
    #   Modulation::Builder.orig_make(location: %s, source: %s)
    # EOF

    # UNCAN_CODE = <<~EOF
    #   proc { RubyVM::InstructionSequence.load_from_binary(Zlib::Inflate.inflate(%s)).eval }
    # EOF

    def self.pack(paths, options = {})
      paths = [paths] unless paths.is_a?(Array)

      entry_point_module_filename = nil
      dictionary = paths.inject({}) do |h, fn|
        STDERR.puts "Processing #{fn}"
        module_source = IO.read(fn)
        entry_point_module_filename ||= fn
        
        # code = (MAKE_CODE % [fn.inspect, module_source.inspect])
        # seq = RubyVM::InstructionSequence.compile(code, options)
        # canned = Zlib::Deflate.deflate(seq.to_binary)
        # h[fn] = UNCAN_CODE % canned.inspect

        zipped = Zlib::Deflate.deflate(module_source)

        code = "z.inflate(%s)" % zipped.inspect
        h[fn] = UNZIP_CODE % [fn.inspect, code]
        h
      end

      (BOOTSTRAP % [
        dictionary.map { |fn, code| ("%s => %s" % [fn.inspect, code]).chomp }.join(','),
        "#{entry_point_module_filename}".inspect
      ]).chomp.gsub(/\n+/, "\n")
    end

    def self.generate_bootstrap(module_dictionary, entry_point)
      BOOTSTRAP % [
        module_dictionary.map do |fn, code|
          ("%s => %s" % [fn.inspect, code]).chomp
        end.join(','),
        entry_point.inspect
      ]
    end
  end
end
