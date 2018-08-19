## [0.10] 2018-08-19

* Refactor and cleanup code.

## [0.9.1] 2018-08-15

* Small fixes to README.

## [0.9] 2018-08-13

* Add support for module reloading.

## [0.8] 2018-08-05

* Add support for nested namespaces.
* Add support for circular dependencies.

## [0.7] 2018-07-29

* Add `MODULE` constant for accessing module from nested namespaces within itself

## [0.6] 2018-07-23

* Add support for using gems as imported modules (experimental feature)
* Add Modulation.full_trace! method for getting full backtrace on errors
* Fix Modulation.transform_export_default_value
* Change name to *Modulation*

## [0.5.1] 2018-07-20

* Fix extend_from, include_from to work with ruby 2.4

## [0.5] 2018-07-19

* Add extend_from, include_from to include imported methods in classes and modules

## [0.4] 2018-07-19

* Refactor code
* Add tests
* Remove namespace feature (owing to the way Ruby handles constants in blocks)

## [0.3.3] 2018-07-09

* Switch to explicit exports
* More documentation
* Better error handling