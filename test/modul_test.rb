require 'minitest/autorun'
require_relative '../lib/modul.rb'

class Modul
  def self.reset!
    @@loaded_modules = {}
  end

  def self.loaded_modules
    @@loaded_modules
  end
end

class FileHandlingTest < Minitest::Test
  def teardown
    Modul.reset!
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
    
    assert_equal([fn_b2, fn_b1, fn_inc], Modul.loaded_modules.keys.sort)
  end
end

class ExportTest < Minitest::Test
  def setup
    @a = import('./modules/a')
  end

  def teardown
    Modul.reset!
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
    Modul.reset!
  end
end

class ExtendFromTest < MiniTest::Test
  def setup
    @m = Module.new
    @m.extend_from('modules/ext')
  end

  def teardown
    Modul.reset!
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
    Modul.reset!
  end

  def test_that_include_from_adds_instance_methods_to_class
    assert_respond_to(@o, :a)
    assert_respond_to(@o, :b)
    assert_raises(NameError) {@o.c}

    assert_equal :a, @o.a
    assert_equal :b, @o.b
  end
end