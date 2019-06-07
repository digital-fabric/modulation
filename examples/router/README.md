# API router

This example demonstrates automatic mapping of modules using their respective
file names using `#import_map`. This technique is useful whenever implementing
APIs that are called using an uniform interface.

In the present example, the [application](app.rb) loads all handler modules into
a hash mapping API names to API handlers.