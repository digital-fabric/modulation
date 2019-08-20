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
      
      Modulation::CANNED = {%s}

      class << Modulation::Builder
        alias_method :orig_make, :make

        def make(info)
          (seq = Modulation::CANNED.delete(info[:location])) ? seq.eval : orig_make(info)
        end
      end

      import(%s).send(:main)
    EOF

    UNCAN_CODE = <<~EOF
      RubyVM::InstructionSequence.load_from_binary(Zlib::Inflate.inflate(%s))
    EOF

    MAKE_CODE = <<~EOF
      Modulation::Builder.orig_make(location: %s, source: %s)
    EOF

    def self.pack(paths, options = {})
      paths = [paths] unless paths.is_a?(Array)

      hide_filenames = options[:hide_filenames]
      entry_point_module_filename = nil
      dictionary = paths.inject({}) do |h, fn|
        module_source = IO.read(fn)
        fn = Digest::MD5.hexdigest(fn) if options[:hide_filenames]
        entry_point_module_filename ||= fn
        code = (MAKE_CODE % [fn.inspect, module_source.inspect])
        seq = RubyVM::InstructionSequence.compile(code, options)
        canned = Zlib::Deflate.deflate(seq.to_binary)
        h[fn] = UNCAN_CODE % canned.inspect
        h
      end

      BOOTSTRAP % [
        dictionary.map { |fn, code| ("%s => %s" % [fn.inspect, code]).chomp }.join(','),
        "@#{entry_point_module_filename}".inspect
      ]
    end
  end
end
