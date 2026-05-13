require "test_helper"

# Exercises Steroids::Extensions::ObjectExtension. Included into ::Object at
# gem boot via `Object.include(...)`, so methods are available on every value.
class ObjectExtensionTest < ActiveSupport::TestCase
  # --------------------------------------------------------------------------------------
  # typed / typed!
  # --------------------------------------------------------------------------------------

  test "typed returns self when class matches" do
    assert_equal "foo", "foo".typed(String)
    assert_equal 42,    42.typed(Integer)
  end

  test "typed returns nil when class does not match" do
    assert_nil "foo".typed(Integer)
    assert_nil 42.typed(String)
  end

  test "typed! returns self when class matches" do
    assert_equal "foo", "foo".typed!(String)
  end

  test "typed! raises TypeError when class does not match" do
    err = assert_raises(TypeError) { "foo".typed!(Integer) }
    assert_match(/Expected .* to be an instance of Integer/, err.message)
  end

  test "typed/typed! pass nil through (typed treats nil as a match)" do
    assert_nil nil.typed(String)
    assert_nil nil.typed!(String)
  end

  # --------------------------------------------------------------------------------------
  # boolean? / ifnil
  # --------------------------------------------------------------------------------------

  test "boolean? is true only for true/false" do
    assert true.boolean?
    assert false.boolean?
    refute nil.boolean?
    refute "true".boolean?
    refute 1.boolean?
    refute 0.boolean?
  end

  test "ifnil returns self when not nil, default when nil" do
    assert_equal "value", "value".ifnil("default")
    assert_equal "default", nil.ifnil("default")
    assert_equal 0, 0.ifnil("default") # 0 is not nil
  end

  # --------------------------------------------------------------------------------------
  # try_method
  # --------------------------------------------------------------------------------------

  test "try_method returns a Method when responded to" do
    method_obj = "hello".try_method(:upcase)
    assert_kind_of Method, method_obj
    assert_equal "HELLO", method_obj.call
  end

  test "try_method returns nil when method is missing" do
    assert_nil "hello".try_method(:no_such_method)
  end

  test "try_method finds private methods too" do
    klass = Class.new do
      private def secret = "shh"
    end
    assert_kind_of Method, klass.new.try_method(:secret)
  end

  # --------------------------------------------------------------------------------------
  # send_apply
  # --------------------------------------------------------------------------------------

  test "send_apply calls a method that exists" do
    assert_equal "HELLO", "hello".send_apply(:upcase)
  end

  test "send_apply returns nil for missing methods (does not raise)" do
    assert_nil "hello".send_apply(:no_such_method)
  end

  test "send_apply respects arity: extra args are trimmed for fixed-arity methods" do
    target = Object.new
    target.define_singleton_method(:greet) { |name| "Hello, #{name}" }

    # Extra positional + kw args are trimmed/filtered by Method#dynamic_arguments_for.
    assert_equal "Hello, Ada", target.send_apply(:greet, "Ada", "extra", junk: true)
  end

  test "send_apply works for zero-arg methods called with extras" do
    target = Object.new
    target.define_singleton_method(:zero_arg) { "ok" }

    assert_equal "ok", target.send_apply(:zero_arg, "ignored", k: 1)
  end

  test "send_apply! returns NoMethodError instance (does not raise) when method missing" do
    result = "hello".send_apply!(:no_such_method)
    assert_kind_of NoMethodError, result
  end

  # --------------------------------------------------------------------------------------
  # instance_apply
  # --------------------------------------------------------------------------------------

  test "instance_apply runs a block in the object's context with matched args" do
    target = Object.new
    target.define_singleton_method(:label) { "T" }

    result = target.instance_apply("a", "b", "c") do |first|
      "#{label}: #{first}"
    end

    assert_equal "T: a", result
  end

  test "instance_apply is a no-op when no block is given" do
    assert_nil Object.new.instance_apply("a")
  end

  # --------------------------------------------------------------------------------------
  # marshallable?
  # --------------------------------------------------------------------------------------

  test "marshallable? is true for primitives and serializable structures" do
    assert "string".marshallable?
    assert 42.marshallable?
    assert({ a: 1, b: [2, 3] }.marshallable?)
  end

  test "marshallable? is false for unmarshallable values (Proc, IO)" do
    refute(->(x) { x }.marshallable?)
    refute $stdout.marshallable?
  end

  # --------------------------------------------------------------------------------------
  # serializable? / deep_serialize
  # --------------------------------------------------------------------------------------

  test "serializable? is true for nested primitives" do
    assert "str".serializable?
    assert 1.serializable?
    assert true.serializable?
    assert nil.serializable?
    assert :sym.serializable?
    assert([1, "two", :three].serializable?)
    assert({ a: 1, b: { c: [1, 2] } }.serializable?)
  end

  test "deep_serialize recurses into Hashes and Arrays" do
    input  = { a: 1, b: [{ c: :sym }, 2] }
    output = input.deep_serialize
    assert_equal({ a: 1, b: [{ c: :sym }, 2] }, output)
  end

  test "deep_serialize raises for unserializable leaves when include_object=false" do
    assert_raises(TypeError) do
      { proc: ->(x) { x } }.deep_serialize(false)
    end
  end
end
