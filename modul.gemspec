Gem::Specification.new do |s|
  s.name        = 'modul'
  s.version     = '0.4'
  s.licenses    = ['MIT']
  s.summary     = 'Modul: better dependencies for Ruby'
  s.description = <<~EOF
    Modul provides an alternative way to organize Ruby code. Instead of 
    littering the global namespace with classes and modules, Mrodul lets you 
    explicitly import and export declarations in order to better control 
    dependencies in your codebase.

    With Modul, you always know where a module comes from, and you have full 
    control over which parts of a module's code you wish to expose to the 
    outside world. With Modul, you can more easily write in a functional style 
    with a minimum of boilerplate code.
  EOF
  s.author      = 'Sharon Rosner'
  s.email       = 'ciconia@gmail.com'
  s.files       = ['lib/modul.rb']
  s.homepage    = 'http://github.com/ciconia/modul'
  s.metadata    = {
    "source_code_uri" => "https://github.com/ciconia/modul"
  }
  s.rdoc_options = ["--title", "Modul", "--main", "README.md"]
  s.extra_rdoc_files = ["README.md"]
end