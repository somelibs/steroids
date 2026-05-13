require "test_helper"

# Steroids::Types::SerializableType wraps ActiveModel::Model with an
# attribute-tracking override of `attr_accessor`.
class SerializableTypeTest < ActiveSupport::TestCase
  class SimpleType < Steroids::Types::SerializableType
    attribute :name
    attribute :email
  end

  test "attribute defines readers and writers" do
    instance = SimpleType.new
    instance.name = "Ada"
    instance.email = "ada@example.com"

    assert_equal "Ada", instance.name
    assert_equal "ada@example.com", instance.email
  end

  test "attributes are tracked on the class for ActiveModel serialization" do
    assert_equal [:name, :email], SimpleType.attributes
  end

  test "attributes accepts mass assignment via ActiveModel::Model initializer" do
    instance = SimpleType.new(name: "Bob", email: "bob@example.com")
    assert_equal "Bob", instance.name
    assert_equal "bob@example.com", instance.email
  end

  test "attr_accessor is aliased to attributes (so it tracks too)" do
    klass = Class.new(Steroids::Types::SerializableType) do
      attr_accessor :foo, :bar
    end

    assert_equal [:foo, :bar], klass.attributes
    instance = klass.new(foo: 1, bar: 2)
    assert_equal 1, instance.foo
    assert_equal 2, instance.bar
  end
end
