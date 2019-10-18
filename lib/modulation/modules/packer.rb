# frozen_string_literal: true

export :pack

require 'modulation/version'
require 'zlib'

BOOTSTRAP_CODE = <<~SRC
  # encoding: ASCII-8BIT
  require 'bundler/inline'

  gemfile do
    source 'https://rubygems.org'
    gem 'modulation', '~> %<modulation_version>s'
  end

  import('@modulation/bootstrap').run(DATA, %<dict_offset>d)
  __END__
  %<data>s
SRC

def pack(paths, _options = {})
  paths = [paths] unless paths.is_a?(Array)
  entry_point_filename = File.expand_path(paths.first)

  deps = collect_dependencies(paths)
  package_info = generate_packed_data(deps, entry_point_filename)
  generate_bootstrap(package_info, entry_point_filename)
end

def collect_dependencies(paths)
  paths.each_with_object([]) do |fn, deps|
    mod = import(File.expand_path(fn))
    deps << File.expand_path(fn)
    mod.__traverse_dependencies { |m| deps << m.__module_info[:location] }
  end
end

def generate_packed_data(deps, entry_point_filename)
  files = deps.each_with_object({}) do |path, dict|
    dict[path] = IO.read(path)
  end
  pack_files(files, entry_point_filename)
end

def pack_files(files, entry_point_filename)
  dictionary = { entry_point: entry_point_filename }
  data = (+'').encode('ASCII-8BIT')
  last_offset = 0
  files.each_with_object(dictionary) do |(path, content), dict|
    last_offset = add_packed_file(path, content, data, dict, last_offset)
  end
  data << Zlib::Deflate.deflate(dictionary.inspect)

  { dict_offset: last_offset, data: data }
end

def add_packed_file(path, content, data, dict, last_offset)
  zipped = Zlib::Deflate.deflate(content)
  size = zipped.bytesize

  data << zipped
  dict[path] = [last_offset, size]
  last_offset + size
end

def generate_bootstrap(package_info, _entry_point)
  format(
    bootstrap_template,
    modulation_version: Modulation::VERSION,
    dict_offset:        package_info[:dict_offset],
    data:               package_info[:data]
  )
end

def bootstrap_template
  BOOTSTRAP_CODE.encode('ASCII-8BIT').gsub(/^\s+/, '').chomp
end
