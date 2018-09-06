require_relative('lib/modulation/version')

Gem::Specification.new do |s|
  s.name        = 'modulation'
  s.version     = Modulation::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Modulation: better dependency management for Ruby'
  s.description = <<~EOF
    Modulation provides an better way to organize Ruby code. Modulation lets
    you explicitly import and export declarations in order to better control
    dependencies in your codebase. Modulation helps you refrain from littering
    the global namespace with a myriad modules, or declaring complex nested
    class hierarchies.
  EOF
  s.author        = 'Sharon Rosner'
  s.email         = 'ciconia@gmail.com'
  s.files         = `git ls-files README.md CHANGELOG.md lib bin`.split
  s.homepage      = 'http://github.com/ciconia/modulation'
  s.metadata      = { "source_code_uri" => "https://github.com/ciconia/modulation" }
  s.rdoc_options  = ["--title", "Modulation", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md", "CHANGELOG.md"]
  s.executables   = ['rbm']

  s.add_development_dependency 'minitest', '5.11.3'
  s.add_development_dependency 'redis', '4.0.1'
end
