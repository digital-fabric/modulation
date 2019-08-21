# Packed app example

To package the application in this directory, run the following command:

```bash
$ mdl pack app.rb > package.rb
```

You can then run the packaged app just like a normal Ruby application:

```bash
$ ruby package.rb
```

Note that `mdl` will automatically process all the app's dependencies and
include them in the package. The [resulting file](package.rb) contains some
bootstrapping code as well as a zipped representation of each module's source
code.

In the future, packaging apps will also support:

- Binary code representation (using
  [`RubyVM::InstructionSequence`](https://ruby-doc.org/core-2.6.1/RubyVM/InstructionSequence.html))
- File path obfuscation
- Smaller packed files
- Support for automatically installing and loading gem dependencies using
  [Bundler](https://bundler.io/v2.0/guides/bundler_in_a_single_file_ruby_script.html)

For more information see the Modulation
[README](../../#readme)