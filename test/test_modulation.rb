require 'minitest/autorun'
require_relative '../lib/modulation.rb'
Modulation.full_backtrace!

class Modulation
  def self.reset!
    @@loaded_modules = {}
  end

  def self.loaded_modules
    @@loaded_modules
  end
end

class FileHandlingTest < Minitest::Test
  def setup
    Modulation.reset!
  end
  
  def teardown
    Modulation.reset!
  end

  def test_that_import_raises_on_file_not_found
    assert_raises(Exception) {import('./not_found')}
  end


  def test_that_import_takes_filename_without_rb_extension
    a1 = import('./modules/a')
    a2 = import('./modules/a.rb')

    assert_same(a1, a2)
  end

  def test_that_import_loads_the_same_file_only_once
    $inc = 0
    import('./modules/inc')
    import('./modules/inc')

    assert_equal(1, $inc)
  end

  def test_that_filenames_are_always_relative
    $inc = 0
    import('./modules/b1')
    assert_equal(1, $inc)

    fn_b1 =   File.expand_path('modules/b1.rb', File.dirname(__FILE__))
    fn_b2 =   File.expand_path('modules/b/b2.rb', File.dirname(__FILE__))
    fn_inc =  File.expand_path('modules/inc.rb', File.dirname(__FILE__))
    
    assert_equal([fn_b2, fn_b1, fn_inc], Modulation.loaded_modules.keys.sort)
  end
end

class ExportTest < Minitest::Test
  def setup
    @a = import('./modules/a')
  end

  def teardown
    Modulation.reset!
  end

  def test_that_non_exported_consts_are_not_accessible
    assert_raises(NameError) {@a::PrivateClass}
  end

  def test_that_exported_consts_are_accessible
    assert_equal 42, @a::ExportedConstant
  end

  def test_that_non_exported_methods_are_not_accessible
    assert_raises(NameError) {@a.private_method}
  end

  def test_that_exported_methods_are_accessible
    assert_equal "private", @a.exported_method
  end

  def test_that_private_class_is_accessible_to_module
    assert_kind_of Class, @a.access_private_class
  end
end

class ExportDefaultTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end
end

class ExtendFromTest < MiniTest::Test
  def setup
    @m = Module.new
    @m.extend_from('modules/ext')
  end

  def teardown
    Modulation.reset!
  end

  def test_that_extend_from_extends_a_module
    assert_respond_to(@m, :a)
    assert_respond_to(@m, :b)
    assert_raises(NameError) {@m.c}

    assert_equal :a, @m.a
    assert_equal :b, @m.b
  end
end

class IncludeFromTest < MiniTest::Test
  def setup
    @c = Class.new
    @c.include_from('modules/ext')

    @o = @c.new
  end

  def teardown
    Modulation.reset!
  end

  def test_that_include_from_adds_instance_methods_to_class
    assert_respond_to(@o, :a)
    assert_respond_to(@o, :b)
    assert_raises(NameError) {@o.c}

    assert_equal :a, @o.a
    assert_equal :b, @o.b
  end
end

class DefaultModuleWithReexportedConstants < MiniTest::Test
  def test_that_default_module_includes_reexported_constants
    @m = import('modules/default_module')
    assert_equal(42, @m::CONST)
    assert_equal("hello!", @m::ImportedClass.new.greet)
  end
end

class GemTest < MiniTest::Test
  def setup
    Object.remove_const(:MyGem) rescue nil
  end

  def teardown
    Object.remove_const(:MyGem) rescue nil
    Modulation.reset!
  end

  def test_that_a_required_gem_defines_its_namespace
    require_relative './modules/my_gem'

    assert(MyGem.is_a?(Module))

    assert_equal(42, MyGem::CONST)
    assert_kind_of(Class, MyGem::MyClass)
    assert_equal("hello!", MyGem::MyClass.new.greet)
  end

  def test_that_an_imported_gem_exports_its_namespace
    @m = import('modules/my_gem')

    assert_equal(42, @m::CONST)
    assert_kind_of(Class, @m::MyClass)
    assert_equal("hello!", @m::MyClass.new.greet)
  end
end

class ModuleRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_contained_modules_have_access_to_containing_module
    m = import('modules/contained')
    
    assert_equal(42, m.meaning_of_life)
    assert_equal(42, m::ContainedModule.test)

    assert_raises(NameError) {m::ContainedModule.test_private}
  end
end

class CircularRefTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_circular_references_work
    m1 = import('modules/circular1')
    m2 = import('modules/circular2')

    assert_equal(42, m1.meaning_of_life)
    assert_equal(42, m2.reexported)
  end
end

class ExtendFromTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_extend_from_doesnt_mix_private_methods
    m = Module.new
    m.extend_from('modules/extend_from1')
    m.extend_from('modules/extend_from2')

    assert_equal(1, m.method1)
    assert_equal(2, m.method2)
  end
end

class NamespaceTest < MiniTest::Test
  def teardown
    Modulation.reset!
  end

  def test_that_namespace_acts_like_a_module
    m = import('modules/namespace')
    
    assert_kind_of(Module, m::PublicNamespace)
    assert_equal("Hello", m::PublicNamespace.greeting)
    assert_raises(NameError) {m::PublicNamespace.secret}

    assert_equal("Hello", m.access_public_namespace_public_method)
    assert_raises(NameError) {m.access_public_namespace_private_method}

    assert_raises(NameError) {m::PrivateNamespace}
    assert_kind_of(Module, m.access_private_namespace)
    assert_equal("select 1", m.access_private_namespace.sql)
    assert_raises(NameError) {m.access_private_namespace.secret}
  end

  def test_that_namespace_consts_are_qualified_correctly
    m = import('modules/namespace_const')
    assert_equal("select 1", m::SQL.sql)
    assert_equal("select 1", m::SQL::SQL)
    assert_raises(NameError) {m::SQL::SECRET}
  end

  def test_that_namespace_can_access_methods_on_top_level_module
    m = import('modules/namespace_module_access')
    assert_equal("select 42", m::SQL.format)
  end

  def test_that_namespaces_can_access_each_other
    m = import('modules/namespace_cross_access')
    assert_equal("select 42", m::SQL.format)
    assert_raises(NameError) {m::Settings}
    assert_raises(NameError) {m::SQL.access_secret_method}
    assert_raises(NameError) {m::SQL.access_secret_const}
    assert_raises(NameError) {m::SQL.secret}
  end
end