require "test_helper"

class NoticableMethodsTest < ActiveSupport::TestCase
  class NoticableTestClass
    include Steroids::Support::NoticableMethods
    
    def initialize
      # Initialize noticable
    end
  end
  
  setup do
    @noticable = NoticableTestClass.new
  end
  
  # NoticableCollection tests
  test "errors collection starts empty" do
    assert_not @noticable.errors.any?
    assert_not @noticable.errors?
  end
  
  test "errors.add accepts string message only" do
    @noticable.errors.add("Error message")
    
    assert @noticable.errors.any?
    assert @noticable.errors?
    assert_includes @noticable.errors.full_messages, "Error message"
  end
  
  test "errors.add accepts message with exception" do
    exception = StandardError.new("Original error")
    @noticable.errors.add("Wrapped error", exception)
    
    assert @noticable.errors.any?
    assert_equal "Wrapped error", @noticable.errors.full_messages
  end
  
  test "errors.add does NOT accept symbol as first argument" do
    assert_raises(TypeError) do
      @noticable.errors.add(:base, "Message")
    end
  end
  
  test "multiple errors are joined with newlines" do
    @noticable.errors.add("First error")
    @noticable.errors.add("Second error")
    @noticable.errors.add("Third error")
    
    expected = "First error\nSecond error\nThird error"
    assert_equal expected, @noticable.errors.full_messages
  end
  
  test "notices collection works similarly to errors" do
    @noticable.notices.add("First notice")
    @noticable.notices.add("Second notice")
    
    assert @noticable.notices.any?
    assert_equal "First notice\nSecond notice", @noticable.notices.full_messages
  end
  
  test "success? returns true when no errors" do
    assert @noticable.success?
    
    @noticable.notices.add("Just a notice")
    assert @noticable.success?
    
    @noticable.errors.add("An error")
    assert_not @noticable.success?
  end
  
  test "errors? returns true when errors exist" do
    assert_not @noticable.errors?
    
    @noticable.errors.add("An error")
    assert @noticable.errors?
  end
  
  test "notice returns error messages when errors exist" do
    @noticable.errors.add("Error 1")
    @noticable.errors.add("Error 2")
    
    assert_equal "Error 1\nError 2", @noticable.notice
    assert_equal @noticable.notice, @noticable.errors.full_messages  # full_messages is the actual method
  end
  
  test "notice returns success notice when no errors" do
    class CustomNoticableClass
      include Steroids::Support::NoticableMethods
      
      def self.steroids_noticable_notice
        "Custom success message"
      end
    end
    
    noticable = CustomNoticableClass.new
    assert_equal "Custom success message", noticable.notice
  end
  
  test "notice returns notices when present and no errors" do
    @noticable.notices.add("Notice 1")
    @noticable.notices.add("Notice 2")
    
    assert_equal "Notice 1\nNotice 2", @noticable.notice
  end
  
  test "errors collection can use << operator" do
    @noticable.errors << "Error via operator"
    
    assert @noticable.errors?
    assert_includes @noticable.errors.full_messages, "Error via operator"
  end
  
  test "merge combines errors from another noticable" do
    other = NoticableTestClass.new
    other.errors.add("Other error 1")
    other.errors.add("Other error 2")
    other.notices.add("Other notice")
    
    @noticable.errors.add("My error")
    @noticable.noticable.merge(other.noticable)
    
    # Check that errors were merged
    errors_array = @noticable.errors.map { |e| e[:message] }
    assert_includes errors_array, "My error"
    assert_equal 3, @noticable.errors.to_a.size
  end
  
  # Class method tests
  test "success_notice class method sets default notice" do
    class ServiceWithNotice
      include Steroids::Support::NoticableMethods
      success_notice "Operation was successful"
    end
    
    service = ServiceWithNotice.new
    assert_equal "Operation was successful", service.notice
  end
  
  test "default success notice uses humanized class name" do
    class MySpecialOperation
      include Steroids::Support::NoticableMethods
    end
    
    operation = MySpecialOperation.new
    assert_equal "My special operation succeeded", operation.notice
  end
end