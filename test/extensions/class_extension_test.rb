require "test_helper"

# Steroids::Extensions::ClassExtension is included into ::Class at gem boot.
# Powers typed-attribute declarations and anonymous-class building.
class ClassExtensionTest < ActiveSupport::TestCase
  # --------------------------------------------------------------------------------------
  # attribute — typed reader+writer with defaults
  # --------------------------------------------------------------------------------------

  test "attribute defines a reader and writer" do
    klass = Class.new do
      attribute :name, default: "anon", type: "String"
    end

    instance = klass.new
    assert_equal "anon", instance.name # reader → default
    instance.name = "Ada"
    assert_equal "Ada", instance.name
  end

  test "attribute enforces the declared type via typed!" do
    klass = Class.new do
      attribute :count, default: 0, type: "Integer"
    end
    instance = klass.new

    assert_raises(TypeError) { instance.count = "not-an-int" }
  end

  test "attribute with allow_nil: true lets nil through without typecheck" do
    klass = Class.new do
      attribute :tag, type: "String", allow_nil: true
    end
    instance = klass.new
    assert_nothing_raised { instance.tag = nil }
    assert_nil instance.tag
  end

  test "steroids_attributes_set tracks every declared attribute" do
    klass = Class.new do
      attribute :a
      attribute :b
    end
    assert_equal [:a, :b], klass.steroids_attributes_set
  end

  # --------------------------------------------------------------------------------------
  # delegate_alias
  # --------------------------------------------------------------------------------------

  test "delegate_alias forwards through send_apply" do
    inner = Class.new { def shout(msg) = msg.upcase }.new

    outer_class = Class.new do
      attr_accessor :backend

      delegate_alias :yell, to: :backend, method: :shout
    end

    outer = outer_class.new
    outer.backend = inner

    assert_equal "HELLO", outer.yell("hello")
  end

  # --------------------------------------------------------------------------------------
  # build_anonymous — named anonymous classes
  # --------------------------------------------------------------------------------------

  test "build_anonymous returns a class whose name is the demodulized constant" do
    parent = Class.new
    klass = Class.build_anonymous("Built", parent) { def hello = :hi }
    assert_equal "Built", klass.name
    assert klass.anonymous?
    assert_equal :hi, klass.new.hello
  ensure
    Object.send(:remove_const, :Built) if defined?(::Built)
  end
end
