require "test_helper"

# Steroids::Extensions::ArrayExtension is included into ::Array at gem boot.
class ArrayExtensionTest < ActiveSupport::TestCase
  # --------------------------------------------------------------------------------------
  # cast
  # --------------------------------------------------------------------------------------

  test "cast returns the matching element" do
    assert_equal :draft, [:draft, :published, :archived].cast(:draft)
    assert_equal "a",    ["a", "b"].cast("a")
  end

  test "cast raises ElementNotFound when value is missing" do
    err = assert_raises(Steroids::Extensions::ArrayExtension::ElementNotFound) do
      [:draft, :published].cast(:unknown)
    end
    assert_match(/Cast: Element not found/, err.message)
  end

  test "cast with indifferent_access=true matches across symbol/string" do
    arr = [:draft, :published]
    assert_equal :draft, arr.cast("draft", true)
  end

  test "cast with indifferent_access=false (default) is strict" do
    assert_raises(Steroids::Extensions::ArrayExtension::ElementNotFound) do
      [:draft, :published].cast("draft")
    end
  end

  # --------------------------------------------------------------------------------------
  # find_map
  # --------------------------------------------------------------------------------------

  test "find_map returns the first truthy block result" do
    result = [1, 2, 3, 4].find_map { |n| n.even? ? "even:#{n}" : nil }
    assert_equal "even:2", result
  end

  test "find_map returns nil when no element yields a truthy value" do
    assert_nil([1, 3, 5].find_map { |n| n.even? ? n : nil })
  end

  test "find_map without a block returns an Enumerator" do
    enum = [1, 2, 3].find_map
    assert_kind_of Enumerator, enum
  end

  test "find_map short-circuits — does not call block past first hit" do
    calls = []
    [1, 2, 3, 4].find_map do |n|
      calls << n
      n == 2 ? "stop" : nil
    end
    assert_equal [1, 2], calls
  end
end
