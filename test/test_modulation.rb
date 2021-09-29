# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'tempfile'
require 'modulation'

Modulation.full_backtrace!

def Modulation.with_clean_backtrace
  @full_backtrace = false
  yield
ensure
  @full_backtrace = true
end

MODULES_DIR = File.join(__dir__, 'modules')
RELOADED_FN = File.join(MODULES_DIR, 'reloaded.rb')

class Minitest::Test
  def setup
    Modulation.reset!
  end

  def teardown
    Modulation.reset!
  end
end

class FileHandlingTest < Minitest::Test
  def test_that_import_raises_on_file_not_found
    assert_raises(Exception) { import('./not_found') }
  end

  def test_that_import_takes_filename_without_rb_extension
    a1 = import('./modules/a')
    a2 = import('./modules/a.rb')

    assert_same(a1, a2)
  end

  def test_that_import_loads_the_same_file_only_once
    Thread.current[:inc] = 0
    import('./modules/inc')
    import('./modules/inc')

    assert_equal(1, Thread.current[:inc])
  end

  def test_that_filenames_are_always_relative
    Thread.current[:inc] = 0
    import('./modules/b1')
    assert_equal(1, Thread.current[:inc])

    fn_b1 =   File.expand_path('modules/b1.rb', __dir__)
    fn_b2 =   File.expand_path('modules/b/b2.rb', __dir__)
    fn_inc =  File.expand_path('modules/inc.rb', __dir__)
    assert_equal([fn_b2, fn_b1, fn_inc], Modulation.loaded_modules.keys.sort)
  end
end

class ExportTest < Minitest::Test
  def setup
    super
    @a = import('./modules/a')
  end

  def test_that_non_exported_consts_are_not_accessible
    assert_raises(NameError) { @a::PrivateClass }
  end

  def test_that_non_exported_consts_are_saved_in_module_info
    assert_equal(@a.__module_info[:private_constants], [:PrivateClass])
  end

  def test_that_exported_consts_are_accessible
    assert_equal 42, @a::ExportedConstant
  end

  def test_that_non_exported_methods_are_not_accessible
    assert_raises(NameError) { @a.private_method }
  end

  def test_that_exported_methods_are_accessible
    assert_equal 'private', @a.exported_method
  end

  def test_that_private_class_is_accessible_to_module
    assert_kind_of Class, @a.access_private_class
  end

  def test_that_not_found_export_symbol_raises
    assert_raises(NameError) do
      import('./modules/missing_exported_const')
    end

    assert_raises(NameError) do
      import('./modules/missing_exported_method')
    end
  end

  def test_hash_export
    m = import('./modules/hash_export')
    assert_equal 42, m::Everything
    assert_equal :baz, m.foo
    assert_equal 'ZZZ', m.bar
    assert_equal 'Hello world!', m.greeting('world')
  end

  def test_additive_export
    m = import './modules/additive'

    assert_equal :foo, m.foo
    assert_equal :bar, m.bar
    assert_equal :baz, m::BAZ
  end

  def test_export_with_export_default
    assert_raises { import './modules/export_with_export_default' }
  end

  def hijack_error
    yield
  rescue StandardError => e
    e
  end

  def test_that_bad_exports_show_correct_backtrace
    Modulation.with_clean_backtrace do
      import_line = __LINE__
      error = hijack_error { import './modules/bad_export' }

      assert_kind_of(NameError, error)
      module_file = File.expand_path('./modules/bad_export.rb', __dir__)
      assert_match(/^#{module_file}\:1/, error.backtrace[0])
      assert_match(/^#{__FILE__}\:#{import_line + 1}/, error.backtrace[1])
    end
  end
end

class ExportFromReceiverTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_export_from_receiver
    m = import './modules/receiver'

    assert_equal :foo, m.foo
    assert_equal :baz, m.bar

    assert_equal 42, m::MOL

    assert_raises(NameError) { m.baz }
  end

  def test_missing_receiver
    assert_raises(NameError) { import './modules/missing_receiver' }
  end

  def test_export_from_subclass
    m = import './modules/receiver_sub'

    assert_equal :foo, m.foo
    assert_equal :bar, m.bar
  end
end

class ExposeTest < MiniTest::Test
  def setup
    super
    @a = import('./modules/a').__expose!
  end

  def test_that_expose_exposes_private_methods
    assert_equal(@a.private_method, 'private')
    assert_equal(@a::PrivateClass.class, Class)
  end
end

class ExportDefaultTest < MiniTest::Test
  def teardown
    begin
      FileUtils.rm(RELOADED_FN)
    rescue StandardError
      nil
    end
    Modulation.reset!
  end

  def write_template(code)
    Modulation.reset!
    File.open(RELOADED_FN, 'w+') { |f| f << code }
  end

  def test_default_export_types
    write_template('export_default :abc')
    assert_raises(NameError) { import('./modules/reloaded') }

    write_template('export_default 42')
    assert_raises(TypeError) { import('./modules/reloaded') }

    write_template('export_default false')
    assert_raises(TypeError) { import('./modules/reloaded') }

    write_template("export_default 'abc'")
    assert_equal('abc', import('./modules/reloaded'))
  end

  def test_that_not_found_export__default_symbol_raises
    assert_raises(NameError) do
      import('./modules/missing_export_default_const')
    end

    assert_raises(NameError) do
      import('./modules/missing_export_default_method')
    end
  end

  # def test_circular_export_default
  #   c1 = import('./modules/circular_default1')
  #   c2 = import('./modules/circular_default2')

  #   assert_kind_of Class, c1
  #   assert_kind_of Class, c2

  #   assert_equal(:bar, c1.new.foo)
  #   assert_equal(:baz, c2.new.bar)
  # end
end

class ExtendFrom1Test < MiniTest::Test
  def setup
    super
    @m = Module.new
    @m.extend_from('modules/ext')
  end

  def test_that_extend_from_extends_a_module
    assert_respond_to(@m, :a)
    assert_respond_to(@m, :b)
    assert_raises(NameError) { @m.c }

    assert_equal :a, @m.a
    assert_equal :b, @m.b
  end
end

class ExtendFrom2Test < MiniTest::Test
  def setup
    super
    @m = Module.new
    @m.extend_from('./modules/extend_from1')
    @m.extend_from('./modules/extend_from2')
  end

  def test_that_extend_from_doesnt_mix_private_methods
    assert_equal(1, @m.method1)
    assert_equal(2, @m.method2)
  end

  def test_that_extend_from_adds_constants
    assert_equal(:bar, @m::FOO)
  end
end

class IncludeFromTest < MiniTest::Test
  def setup
    super
    @c = Class.new
    @c.include_from('modules/ext')
  end

  def test_that_include_from_adds_instance_methods_to_class
    @o = @c.new
    assert_respond_to(@o, :a)
    assert_respond_to(@o, :b)
    assert_raises(NameError) { @o.c }

    assert_equal :a, @o.a
    assert_equal :b, @o.b
  end

  def test_that_include_from_adds_constants_to_class
    o = @c::C.new

    assert_equal :bar, o.foo

    assert_raises(NameError) { @c::D }
  end

  def test_that_include_from_accepts_list_of_symbols
    c = Class.new
    c.include_from('modules/ext', :a)
    o = c.new
    assert_respond_to(o, :a)
    assert(!o.respond_to?(:b))
    assert_raises(NameError) { c::C }

    c = Class.new
    c.include_from('modules/ext', :b, :C)
    o = c.new
    assert(!o.respond_to?(:a))
    assert_respond_to(o, :b)
    assert_equal(:bar, c::C.new.foo)

    c = Class.new
    assert_raises(NameError) { c.include_from('modules/ext', :D) }
  end
end

class DefaultModuleWithReexportedConstantsTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_default_module_includes_reexported_constants
    @m = import('./modules/default_module')
    assert_equal('forty two', @m::CONST)
    assert_equal('hello!', @m::ImportedClass.new.greet)
  end
end

class GemTest < MiniTest::Test
  def setup
    super
    Object.remove_const(:MyGem)
  rescue StandardError
    nil
  end

  def teardown
    begin
      Object.remove_const(:MyGem)
    rescue StandardError
      nil
    end
    super
  end

  def test_that_a_required_gem_defines_its_namespace
    require_relative './modules/my_gem'

    assert(MyGem.is_a?(Module))

    assert_equal('forty two', MyGem::CONST)
    assert_kind_of(Class, MyGem::MyClass)
    assert_equal('hello!', MyGem::MyClass.new.greet)
  end

  def test_that_an_imported_gem_exports_its_namespace
    @m = import('./modules/my_gem')

    assert_equal('forty two', @m::CONST)
    assert_kind_of(Class, @m::MyClass)
    assert_equal('hello!', @m::MyClass.new.greet)
  end

  def test_that_importing_a_regular_gem_raises_error
    e = assert_raises(LoadError) { import('redis/hash_ring') }
    assert_match(/use `require` instead/, e.message)

    e = assert_raises(LoadError) { import('redis') }
    assert_match(/use `require` instead/, e.message)
  end
end

class ModuleRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_contained_modules_have_access_to_containing_module
    m = import('./modules/contained')

    assert_equal(42, m.meaning_of_life)
    assert_equal(42, m::ContainedModule.test)

    assert_raises(NameError) { m::ContainedModule.test_private }
  end
end

class CircularRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_circular_references_work
    m1 = import('./modules/circular1')
    m2 = import('./modules/circular2')

    assert_equal(42, m1.meaning_of_life)
    assert_equal(42, m2.reexported)
  end
end

class InstanceVariablesTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_instance_variables_are_accessible
    m = import('./modules/instance_vars')
    assert_nil(m.get)
    m.set(42)
    assert_equal(42, m.get)

    assert_nil(m.name)
    m.name = 'abc'
    assert_equal('abc', m.name)
  end
end

require 'fileutils'

class ReloadTest < MiniTest::Test
  def teardown
    FileUtils.rm(RELOADED_FN)
    Modulation.reset!
  end

  def write_template(path)
    File.open(RELOADED_FN, 'w+') { |f| f << IO.read(path) }
  end

  def test_that_a_module_can_be_reloaded
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')

    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    m.reload_dependency

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) { m.hide_and_seek }
  end

  def test_that_a_module_can_be_reloaded_without_breaking_deps
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')

    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    Modulation.reload(RELOADED_FN)

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) { m.hide_and_seek }
  end

  def test_reloading_by_filename
    write_template(File.join(MODULES_DIR, 'template_reloaded_1.rb'))
    m = import('./modules/reloaded_user')

    assert_equal(m.call_me, 'Saul')
    assert_equal(m.hide_and_seek, 42)

    write_template(File.join(MODULES_DIR, 'template_reloaded_2.rb'))
    Modulation.reload(RELOADED_FN)

    assert_equal(m.call_me, 'David')
    assert_raises(NameError) { m.hide_and_seek }
  end

  def test_that_a_default_export_can_be_reloaded
    write_template(File.join(MODULES_DIR, 'template_reloaded_default_1.rb'))
    m = import('./modules/reloaded')

    assert_kind_of(String, m)
    assert_equal('Hello', m)

    write_template(File.join(MODULES_DIR, 'template_reloaded_default_2.rb'))
    m = m.__reload!

    assert_kind_of(Hash, m)
    assert_equal({ 'Hello' => 'world' }, m)
  end
end

class MockTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  module Mockery
    module_function

    def message
      'mocked'
    end

    SQL = 'select id from mocked'
  end

  def test_unmocked_module_user
    m = import('./modules/mock_user')
    assert_equal('not mocked', m.message)
    assert_equal('select id from not_mocked', m.sql_const)
  end

  def test_that_mock_with_block_provides_a_mock_module
    Modulation.mock('./modules/mocked', Mockery) do
      m = import('./modules/mock_user')
      assert_equal('mocked', m.message)
      assert_equal('select id from mocked', m.sql_const)
    end
  end
end

class ModuleTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_transitive_module_can_be_included_in_module
    m = import('./modules/include_module')
    assert_equal('bar', m.foo)
  end
end

class InstanceVariableTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_instance_variables_can_be_set_outside_of_methods
    m = import('./modules/instance_var')
    assert_equal('bar', m.foo)
  end
end

class AutoImportTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_auto_import_loads_module
    m = import('./modules/auto_import')

    fn1 = File.expand_path('modules/auto_import.rb', __dir__)
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m.foo)

    fn2 = File.expand_path('modules/auto_import_bar.rb', __dir__)
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)
  end

  def test_auto_import_in_nested_module
    m = import('./modules/auto_import_nested')

    fn1 = File.expand_path('modules/auto_import_nested.rb', __dir__)
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m::BAR)

    fn2 = File.expand_path('modules/auto_import_bar.rb', __dir__)
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)
  end

  def test_auto_import_with_hash_argument
    m = import('./modules/auto_import_hash')

    fn1 = File.expand_path('modules/auto_import_hash.rb', __dir__)
    assert_equal([fn1], Modulation.loaded_modules.keys)

    assert_equal('bar', m::M::BAR)

    fn2 = File.expand_path('modules/auto_import_bar.rb', __dir__)
    assert_equal([fn1, fn2], Modulation.loaded_modules.keys)

    assert_equal('baz', m::M::BAZ)

    fn3 = File.expand_path('modules/auto_import_baz.rb', __dir__)
    assert_equal([fn1, fn2, fn3], Modulation.loaded_modules.keys)
  end

  module Foo
    auto_import(
      BAR: './bar'
    )
  end

  def test_auto_import_const_missing_fall_through
    assert_raises(NameError) { Foo::BAZ }
  end
end

class ImportAllTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_import_all_loads_all_files_matching_pattern
    modules = import_all('./modules/subdir')
    assert_kind_of(Array, modules)
    fn_a = File.expand_path('./modules/subdir/a.rb', __dir__)
    fn_b = File.expand_path('./modules/subdir/b.rb', __dir__)
    fn_c1 = File.expand_path('./modules/subdir/c1.rb', __dir__)
    fn_c2 = File.expand_path('./modules/subdir/c2.rb', __dir__)

    paths = Modulation.loaded_modules.keys.sort
    assert_equal([fn_a, fn_b, fn_c1, fn_c2], paths)
    assert_equal(
      Modulation.loaded_modules.keys.sort,
      modules.map { |m| m.__module_info[:location] }.sort
    )
  end
end

class ImportMapTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_import_map_loads_all_files_matching_pattern
    m = import_map('./modules/subdir')
    assert_kind_of(Hash, m)
    assert_equal(4, m.size)
    assert_equal(m['a'], import('./modules/subdir/a'))
    assert_equal(m['b'], import('./modules/subdir/b'))
    assert_equal(m['c1'], import('./modules/subdir/c1'))
    assert_equal(m['c2'], import('./modules/subdir/c2'))
  end

  def test_that_import_map_accepts_options_for_symbol_keys
    m = import_map('./modules/subdir', symbol_keys: true)
    assert_kind_of(Hash, m)
    assert_equal(4, m.size)
    assert_equal(m[:a], import('./modules/subdir/a'))
    assert_equal(m[:b], import('./modules/subdir/b'))
    assert_equal(m[:c1], import('./modules/subdir/c1'))
    assert_equal(m[:c2], import('./modules/subdir/c2'))
  end
end

class AutoImportMapTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_auto_import_map_loads_files_on_demand
    m = auto_import_map('./modules/subdir')
    assert_kind_of(Hash, m)
    assert_equal(0, m.size)
    assert_equal(m['a'], import('./modules/subdir/a'))
    assert_equal(m['b'], import('./modules/subdir/b'))
    assert_equal(2, m.size)
    assert_equal(m['c1'], import('./modules/subdir/c1'))
    assert_equal(m['c2'], import('./modules/subdir/c2'))
    assert_equal(4, m.size)
  end

  def test_that_auto_import_map_works_with_symbols
    m = auto_import_map('./modules/subdir')
    assert_kind_of(Hash, m)
    assert_equal(0, m.size)
    assert_equal(m[:a], import('./modules/subdir/a'))
    assert_equal(m[:b], import('./modules/subdir/b'))
    assert_equal(2, m.size)
    assert_equal(m[:c1], import('./modules/subdir/c1'))
    assert_equal(m[:c2], import('./modules/subdir/c2'))
    assert_equal(4, m.size)
  end

  def test_that_auto_import_map_raises_on_file_not_found
    m = auto_import_map('./modules/subdir')
    assert_kind_of(Hash, m)

    assert_equal(m[:a], import('./modules/subdir/a'))
    assert_equal(1, m.size)

    assert_raises { m[:foo] }
    assert_equal(1, m.size)
  end

  def test_auto_import_map_options
    m = auto_import_map './modules/subdir', not_found: nil
    assert_kind_of Hash, m

    assert_equal import('./modules/subdir/a'), m[:a]
    assert_nil m[:foo]

    m = auto_import_map './modules/subdir', not_found: 42
    assert_kind_of Hash, m

    assert_equal import('./modules/subdir/a'), m[:a]
    assert_equal 42, m[:foo]
  end

  def test_auto_import_map_manual_addition
    m = auto_import_map './modules/subdir'

    assert_raises { m[:foo] }
    assert_equal 0, m.size

    m[:foo] = -> { :bar }
    assert_equal :bar, m[:foo].call
    assert_equal 1, m.size
  end
end

class MODULETest < MiniTest::Test
  def setup
    super
    @m = import('./modules/MODULE')
  end

  def test_MODULE_access
    assert_equal @m, @m.mod
  end

  def test_MODULE_constants
    assert_equal :foo, @m.foo
  end

  def test_MODULE_methods
    assert_equal :bar, @m.bar
  end

  def test_MODULE_send
    assert_equal :baz, @m.baz
  end
end

class CONSTTest < MiniTest::Test
  def setup
    super
    @m = import('./modules/ext')
  end

  def test_qualified_class_name
    assert_equal "(#{@m.inspect})::C", @m::C.inspect

    # c = @m::C.new
    # assert_equal "(#{@m.inspect})::C", c.inspect
  end
end

class DependenciesTest < MiniTest::Test
  def setup
    super
    Thread.current[:inc] = 0
  end

  def test_dependencies
    b1 = import('./modules/b1')
    b2 = import('./modules/b/b2')
    inc = import('./modules/inc')

    assert_equal([b2],  b1.__dependencies)
    assert_equal([inc], b2.__dependencies)
    assert_equal([],    inc.__dependencies)
  end

  def test_traverse_dependencies
    b1 = import('./modules/b1')

    result = []
    b1.__traverse_dependencies do |m|
      fn = m.__module_info[:location]
      result << (fn =~ /([a-z0-9]+)\.rb$/ && Regexp.last_match(1))
    end

    assert_equal(%w[b2 inc], result)
  end

  def test_dependent_modules
    b1 = import('./modules/b1')
    b2 = import('./modules/b/b2')
    inc = import('./modules/inc')

    assert_equal [], b1.__dependent_modules
    assert_equal [b1], b2.__dependent_modules
    assert_equal [b2], inc.__dependent_modules
  end

  # TODO: verify dependencies are updated on module reload
end

class PackerTest < Minitest::Test
  def setup
    super
    Thread.current[:inc] = 0
  end

  Packer = import '@modulation/packer'

  def test_packer
    app_path = File.expand_path('./modules/packer_app.rb', __dir__)
    code = Packer.pack(app_path)
    f = Tempfile.open('packed_app')
    f << code
    f.close

    assert_equal "1\n", `ruby #{f.path}`
  ensure
    f&.unlink
  end
end

class TagsTest < Minitest::Test
  def setup
    super
    begin
      Modulation::Paths.send(:remove_instance_variable, :@tags)
    rescue StandardError
      nil
    end
  end

  def teardown
    super
    begin
      Modulation::Paths.send(:remove_instance_variable, :@tags)
    rescue StandardError
      nil
    end
  end

  def test_expand_tag
    p = Modulation::Paths
    # no tags
    assert_equal 'blah', p.expand_tag('blah')
    assert_raises(RuntimeError) { p.expand_tag('@blah') }
    assert_raises(RuntimeError) { p.expand_tag('@blah/hite') }

    p.add_tags({
                 views:   './modules/subdir',
                 the_app: '../examples/app/app'
               }, "#{__FILE__}:1")

    views_dir = File.expand_path(File.join(__dir__, 'modules/subdir'))
    app_dir = File.expand_path(File.join(__dir__, '../examples/app/app'))

    assert_equal 'blah', p.expand_tag('blah')
    assert_raises(RuntimeError) { p.expand_tag('@blah') }
    assert_equal views_dir, p.expand_tag('@views')

    assert_equal File.join(views_dir, 'a'), p.expand_tag('@views/a')
    assert_equal File.join(views_dir, 'foo'), p.expand_tag('@views/foo')
    assert_equal app_dir, p.expand_tag('@the_app')
    assert_equal File.join(app_dir, 'foo'), p.expand_tag('@the_app/foo')
  end

  def test_tag_based_import
    Modulation.add_tags(views: './modules/subdir')
    m = import('@views/a')
    assert_equal :A, m::A
  end

  def test_tag_based_import_map
    Modulation.add_tags views: './modules/subdir'
    m = import_map('@views')
    assert_kind_of(Hash, m)
    assert_equal(4, m.size)
    assert_equal(m['a'], import('./modules/subdir/a'))
    assert_equal(m['b'], import('./modules/subdir/b'))
    assert_equal(m['c1'], import('./modules/subdir/c1'))
    assert_equal(m['c2'], import('./modules/subdir/c2'))
  end

  def test_tag_based_auto_import_map
    Modulation.add_tags views: './modules/subdir'
    m = auto_import_map('@views')
    assert_kind_of(Hash, m)
    assert_equal(0, m.size)
    assert_equal(m['a'], import('./modules/subdir/a'))
    assert_equal(m['b'], import('./modules/subdir/b'))
    assert_equal(2, m.size)
    assert_equal(m['c1'], import('./modules/subdir/c1'))
    assert_equal(m['c2'], import('./modules/subdir/c2'))
    assert_equal(4, m.size)
  end

  def test_tag_based_include_from
    Modulation.add_tags mods: './modules'
    @c = Class.new
    @c.include_from('@mods/ext')

    @o = @c.new
    assert_respond_to(@o, :a)
    assert_respond_to(@o, :b)
    assert_raises(NameError) { @o.c }

    assert_equal :a, @o.a
    assert_equal :b, @o.b
  end

  def test_tag_based_extend_from
    Modulation.add_tags mods: './modules'
    @m = Module.new
    @m.extend_from('@mods/ext')

    assert_respond_to(@m, :a)
    assert_respond_to(@m, :b)
    assert_raises(NameError) { @m.c }

    assert_equal :a, @m.a
    assert_equal :b, @m.b
  end
end

class ProgrammaticModuleTest < Minitest::Test
  def test_create_with_invalid_arg
    assert_raises(RuntimeError) { Modulation.create }
    assert_raises(RuntimeError) { Modulation.create :foo }
    assert_raises(RuntimeError) { Modulation.create 42 }
  end

  def test_create_with_hash
    m = Modulation.create foo: -> { :foo }, BAR: :bar
    assert_kind_of Module, m
    assert_equal :foo, m.foo
    assert_equal :bar, m::BAR

    m = Modulation.create '@count': 0, incr: -> { @count += 1 }
    assert_equal 1, m.incr
    assert_equal 2, m.incr
    assert_equal 3, m.incr
  end

  def test_create_with_string
    m = Modulation.create <<~RUBY
      export :foo

      def foo
        :bar
      end
    RUBY

    assert_kind_of Module, m
    assert_equal :bar, m.foo
  end

  def test_create_with_block
    m = Modulation.create do
      def foo
        :bar
      end

      @baz = 42
      singleton_class.send :attr_reader, :baz
    end

    assert_kind_of Module, m
    assert_equal :bar, m.foo
    assert_equal 42, m.baz
  end
end

class EmptyTest < Minitest::Test
  def test_empty_module
    m = import('./modules/empty')

    assert_kind_of Module, m
  end
end

class CallableModuleTest < Minitest::Test
  def test_automatic_to_proc
    m = import('./modules/callable')

    assert m.respond_to?(:call)
    assert m.respond_to?(:to_proc)
    assert_equal [1, 4, 9], (1..3).map(&m)

    m = import('./modules/callable_with_to_proc')

    assert m.respond_to?(:call)
    assert m.respond_to?(:to_proc)
    assert_equal [:foo, :foo, :foo], (1..3).map(&m)
  end
end
