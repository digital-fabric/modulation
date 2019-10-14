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

  Bootstrap = import('@modulation/bootstrap')
  Bootstrap.setup(DATA, %<dictionary>s)
  import(%<entry_point>s).send(:main)
  __END__
  %<data>s
SRC

def pack(paths, _options = {})
  paths = [paths] unless paths.is_a?(Array)
  deps = collect_dependencies(paths)
  entry_point_filename = File.expand_path(paths.first)
  dictionary, data = generate_packed_data(deps)
  generate_bootstrap(dictionary, data, entry_point_filename)
end

def collect_dependencies(paths)
  paths.each_with_object([]) do |fn, deps|
    mod = import(File.expand_path(fn))
    deps << File.expand_path(fn)
    mod.__traverse_dependencies { |m| deps << m.__module_info[:location] }
  end
end

def generate_packed_data(deps)
  files = deps.each_with_object({}) do |path, dict|
    dict[path] = IO.read(path)
  end
  pack_files(files)
end

def pack_files(files)
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

def generate_bootstrap(dictionary, data, entry_point)
  format(
    bootstrap_template,
    modulation_version: Modulation::VERSION,
    dictionary: dictionary.inspect,
    entry_point: entry_point.inspect,
    data: data
  )
end

def bootstrap_template
  BOOTSTRAP_CODE.encode('ASCII-8BIT').gsub(/^\s+/, '').chomp
end
