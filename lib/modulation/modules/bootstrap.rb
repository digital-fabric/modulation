# frozen_string_literal: true

export :run, :transform_module_info

require 'zlib'

def run(data, dict_offset)
  setup(data, dict_offset)
  import(@dictionary[:entry_point]).send(:main)
end

def setup(data, dict_offset)
  patch_builder
  @data = data
  @data_offset = data.pos
  @dictionary = read_dictionary(dict_offset)
end

def patch_builder
  class << Modulation::Builder
    alias_method :orig_make, :make
    def make(info)
      info = MODULE.transform_module_info(info)
      orig_make(info)
    end
  end
end

def transform_module_info(info)
  location = info[:location]
  info[:source] = read_file(location) if location
  info
end

def find(path)
  @dictionary[path]
end

def read_dictionary(offset)
  @data.seek(@data_offset + offset)
  eval Zlib::Inflate.inflate(@data.read)
end

def read_file(path)
  (offset, length) = @dictionary[path]
  @data.seek(@data_offset + offset)
  Zlib::Inflate.inflate(@data.read(length))
end
