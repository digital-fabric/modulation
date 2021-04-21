1.0.1 2021-04-21
----------------

* Override inspect method for classes defined in modules (#7)

1.0 2019-10-18
--------------

* Cleanup code
* Obfuscate bootstrap dictionary code in packages
* Move packer, bootstrap, CLI, creator code into stock modules

0.34 2019-10-14
---------------

* Improve README

0.33 2019-10-02
---------------

* Add backward compatibility with Ruby 2.4.x
* Add support for creating modules programmatically
* Fix use of tags in import_map, auto_import_map, include_from, extend_from

0.32 2019-09-03
---------------

* Implement export_from_receiver
* Implement additive exports
* Refactor auto_import_map, add not_found option
* Fix backtrace for exports of missing symbols

0.31 2019-08-28
---------------

* Fix error handling when default_export symbol is not found

0.30 2019-08-24
---------------

* Add symbol_keys option to import_map

0.29 2019-08-23
---------------

* Implement auto_import_map
* Add preliminary inline Gemfile to packaged apps

0.28 2019-08-23
---------------

* Implement tagged sources
* Improve application packer

0.27 2019-08-21
---------------

* Add initial packing functionality

0.26 2019-08-20
---------------

* Add Module#alias_method_once for idempotent method aliasing
* Add dependency introspection API
* Add support for hash in `#export`

0.25 2019-06-07
---------------

* Add `#import_map` method

0.24 2019-05-22
---------------

* Fix usage of Modulation in rake tasks
* Fix behavior when referencing missing consts in modules using `#auto_import`

0.23 2019-05-17
---------------

* Fix regression in `#export_default`

0.22 2019-05-15
---------------

* Export_default of a method now exports a proc calling that method
* Raise error on export of undefined symbols

0.21 2019-02-19
---------------

* Add support for list of symbols to import in `Kernel#include_from`

0.20 2019-01-16
---------------

* Add import_all method

0.19 2019-01-05
---------------

* Move repo to https://github.com/digital-fabric/modulation

0.18 2018-12-30
---------------

* Add auto_import feature for lazy loading of modules

0.17 2018-11-22
---------------

* More documentation

0.16 2018-09-24
---------------

* Add __expose! method for exposing private symbols for testing purposes

0.15 2018-09-09
---------------

* Fix include_from to include only exported constants

0.14 2018-09-09
---------------

* Fix include_from, extend_from to add constants to target object

0.13 2018-09-06
---------------

* Evaluate module code on singleton_class instead of using `#extend self`
* Fix calling `#include` inside imported module
* Add `rbm` binary for running ruby scripts using `#import`

0.12 2018-08-20
---------------

* Fix sanitizing of error backtrace
* Fix importing of gems

0.11 2018-08-20
---------------

* Add Modulation.mock for use in testing

0.10 2018-08-19
---------------

* Refactor and cleanup code

0.9.1 2018-08-15
----------------

* Small fixes to README

0.9 2018-08-13
--------------

* Add support for module reloading

0.8 2018-08-05
--------------

* Add support for nested namespaces
* Add support for circular dependencies

0.7 2018-07-29
--------------

* Add `MODULE` constant for accessing module from nested namespaces within itself

0.6 2018-07-23
--------------

* Add support for using gems as imported modules (experimental feature)
* Add `Modulation.full_trace!` method for getting full backtrace on errors
* Fix `Modulation.transform_export_default_value`
* Change name to *Modulation*

0.5.1 2018-07-20
----------------

* Fix `#extend_from`, `#include_from` to work with ruby 2.4

0.5 2018-07-19
--------------

* Add `#extend_from`, `#include_from` to include imported methods in classes
  and modules

0.4 2018-07-19
--------------

* Refactor code
* Add tests
* Remove namespace feature (owing to the way Ruby handles constants in blocks)

0.3.3 2018-07-09
----------------

* Switch to explicit exports
* More documentation
* Better error handling