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
    i1 = import('./modules/inc')
    i2 = import('./modules/inc')

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
    
    assert_equal(m.meaning_of_life, 42)
    assert_equal(m::ContainedModule.test, 42)

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

    assert_equal(m1.meaning_of_life, 42)
    assert_equal(m2.reexported, 42)
  end
end