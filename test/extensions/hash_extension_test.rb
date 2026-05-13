require "test_helper"

# Steroids::Extensions::HashExtension is included into ::Hash at gem boot.
class HashExtensionTest < ActiveSupport::TestCase
  test "fetch_any returns the value for the first matching key" do
    h = { a: 1, b: 2, c: 3 }
    assert_equal 2, h.fetch_any(:b, :c)
    assert_equal 1, h.fetch_any(:a, :b, :c)
  end

  test "fetch_any returns the value of the first key that exists, even if later keys exist too" do
    h = { a: 1, b: 2 }
    # :a comes first in the *hash* (not the args), so its value wins.
    assert_equal 1, h.fetch_any(:b, :a)
  end

  test "fetch_any returns nil when no provided key matches" do
    assert_nil({ a: 1 }.fetch_any(:b, :c))
  end

  test "fetch_any returns nil for an empty hash" do
    assert_nil({}.fetch_any(:a, :b))
  end
end
