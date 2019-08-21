# frozen_string_literal: true

require_relative '../modulation'
require 'zlib'

module Modulation
  # Implements packing functionality
  module Packing
    BOOTSTRAP = <<~SRC.encode('ASCII-8BIT').chomp
      # encoding: ASCII-8BIT
      require 'bundler/setup'
      require 'modulation/packing'
      Modulation::Packing.setup_packed_app(DATA, %<dictionary>s)
      import(%<entry_point>s).send(:main)
      __END__
      %<data>s
    SRC

    def self.pack(paths, _options = {})
      paths = [paths] unless paths.is_a?(Array)

      entry_point_filename = nil

      last_offset = 0
      data = (+'').encode('ASCII-8BIT')
      dictionary = paths.each_with_object({}) do |path, dict|
        warn "Processing #{path}"
        last_offset = add_packed_module(path, last_offset, dict, data)
        entry_point_filename ||= path
      end

      generate_bootstrap(dictionary, data, entry_point_filename)
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

    def self.setup_packed_app(data, dictionary)
      patch_builder
      Modulation::Builder.const_set(:DATA, data)
      Modulation::Builder.const_set(:DATA_POS, data.pos)
      Modulation::Builder.const_set(:DICTIONARY, dictionary)
    end

    def self.patch_builder
      class << Modulation::Builder
        alias_method :orig_make, :make
        def make(info)
          data_info = Modulation::Builder::DICTIONARY.delete(info[:location])
          data_info ? from_data(info[:location], *data_info) : orig_make(info)
        end

        def from_data(location, offset, length)
          Modulation::Builder::DATA.seek(Modulation::Builder::DATA_POS + offset)
          source = Zlib::Inflate.inflate(DATA.read(length))
          orig_make(location: location, source: source)
        end
      end
    end
  end
end
