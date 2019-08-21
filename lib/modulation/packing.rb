# frozen_string_literal: true

require_relative '../modulation'
require 'zlib'

module Modulation
  # Implements packing functionality
  module Packing
    BOOTSTRAP = <<~SRC.encode('ASCII-8BIT').gsub(/^\s+$/, '').gsub(/\n\n+/, "\n").chomp
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
        zipped = Zlib::Deflate.deflate(IO.read(path))
        entry_point_filename ||= path
        length = zipped.bytesize
        dict[path] = [last_offset, length]
        data << zipped
        last_offset += length
      end

      generate_bootstrap(dictionary, data, entry_point_filename)
    end

    def self.generate_bootstrap(dictionary, data, entry_point)
      format(
        BOOTSTRAP,
        dictionary:   dictionary.inspect,
        entry_point:  entry_point.inspect,
        data:         data
      )
    end

    def self.setup_packed_app(data, dictionary)
      Modulation::Builder.const_set(:DATA, data)
      Modulation::Builder.const_set(:DATA_POS, data.pos)
      Modulation::Builder.const_set(:DICTIONARY, dictionary)

      class << Modulation::Builder
        alias_method :orig_make, :make
        def make(info)
          if (data_info = Modulation::Builder::DICTIONARY.delete(info[:location]))
            from_data(info[:location], *data_info)
          else
            orig_make(info)
          end
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
