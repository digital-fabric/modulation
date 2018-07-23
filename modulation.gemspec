Gem::Specification.new do |s|
  s.name        = 'modulation'
  s.version     = '0.5.1'
  s.licenses    = ['MIT']
  s.summary     = 'Modulation: explicit dependencies for Ruby'
  s.description = <<~EOF
    Modulation provides an alternative way to organize Ruby code. Instead of 
    littering the global namespace with classes and modules, Modulation lets
    you explicitly import and export declarations in order to better control 
    dependencies in your codebase.

    With Modulation, you always know where a module comes from, and you have
    full control over which parts of a module's code you wish to expose to the 
    outside world. With Modulation, you can more easily write in a functional
    style with a minimum of boilerplate code.
  EOF
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = ['lib/modulation.rb']
  s.homepage    = 'http://github.com/ciconia/modulation'
  s.metadata    = {
    "source_code_uri" => "https://github.com/ciconia/modulation"
  }
  s.rdoc_options = ["--title", "Modulation", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
end