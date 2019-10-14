# frozen_string_literal: true

export :setup, :transform_module_info

require 'zlib'

def setup(data, dictionary)
  patch_builder
  @data = data
  @data_offset = data.pos
  @dictionary = dictionary
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
  if find(info[:location])
    info[:source] = read_file(info[:location])
  end
  info
end

def find(path)
  @dictionary[path]
end

def read_file(path)
  (offset, length) = @dictionary[path]
  @data.seek(@data_offset + offset)
  Zlib::Inflate.inflate(@data.read(length))
end