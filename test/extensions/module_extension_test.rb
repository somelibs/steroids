require "test_helper"

# Steroids::Extensions::ModuleExtension is included into ::Module at gem boot.
class ModuleExtensionTest < ActiveSupport::TestCase
  # --------------------------------------------------------------------------------------
  # create_namespace
  # --------------------------------------------------------------------------------------

  test "create_namespace builds a single-level module" do
    ns = Module.new
    inner = ns.create_namespace("Inner")
    assert_kind_of Module, inner
    assert_equal "Inner", inner.name.split("::").last
  end

  test "create_namespace builds nested modules" do
    ns = Module.new
    deep = ns.create_namespace("A::B::C")
    assert_kind_of Module, deep
    assert ns.const_defined?(:A)
    assert ns.const_get(:A).const_defined?(:B)
    assert ns.const_get(:A).const_get(:B).const_defined?(:C)
  end

  test "create_namespace is idempotent — returns the existing module on repeat" do
    ns = Module.new
    first  = ns.create_namespace("X::Y")
    second = ns.create_namespace("X::Y")
    assert_same first, second
  end

  test "create_namespace strips a leading ::" do
    ns = Module.new
    inner = ns.create_namespace("::Z")
    assert_kind_of Module, inner
  end

  # --------------------------------------------------------------------------------------
  # grundclass
  # --------------------------------------------------------------------------------------

  test "grundclass returns self for non-singleton modules" do
    mod = Module.new
    assert_same mod, mod.grundclass
  end
end
