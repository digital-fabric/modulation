* Define root path for non-relative paths

  ```ruby
  Modulation.root = 'lib' # automatically expand path to aboslute path

  import('support/mod') # absolute ref, expands to lib/support/mod
  ```

* Dependency injections

  ```ruby
  # bootstrap.rb
  Modulation[:timeline] = import('timeline')
  ...

  # nodes.rb
  Modulation[:timeline].insert(...)
  ```

  Issue warning on probable collision:

  ```ruby
  Modulation[:timeline] = import('timeline')
  ...
  Modulation[:timeline] = import('timeline') #=> Warning: timeline service already set
  ```

  Raise on missing service:

  ```ruby
  Modulation[:whatever] #=> NameError: unknown service `whatever' referenced
  ```

