require "test_helper"

class BaseServiceTest < ActiveSupport::TestCase
  # Test service classes for testing
  class SuccessfulService < Steroids::Services::Base
    success_notice "Operation completed successfully"
    
    def initialize(value:)
      @value = value
    end
    
    def process
      @value * 2
    end
  end
  
  class FailingService < Steroids::Services::Base
    success_notice "This should not appear"
    
    def process
      errors.add("Something went wrong")
      errors.add("Another error occurred")
    end
  end
  
  class ExceptionService < Steroids::Services::Base
    def process
      raise StandardError, "Unexpected error"
    end
  end
  
  class ValidatedService < Steroids::Services::Base
    success_notice "Validated successfully"
    
    def initialize(email:)
      @email = email
    end
    
    private
    
    def process
      validate_email!
      "Email is valid: #{@email}"
    end
    
    def validate_email!
      if @email.blank?
        errors.add("Email cannot be blank")
        drop!
      end
      
      unless @email.include?("@")
        errors.add("Email format is invalid")
        drop!
      end
    end
  end
  
  class CallbackService < Steroids::Services::Base
    before_process :setup
    after_process :cleanup
    
    attr_reader :setup_called, :cleanup_called
    
    def initialize
      @setup_called = false
      @cleanup_called = false
    end
    
    def process
      "processed"
    end
    
    private
    
    def setup
      @setup_called = true
    end
    
    def cleanup(result)
      @cleanup_called = true
    end
  end
  
  # Basic functionality tests
  test "successful service returns success" do
    service = SuccessfulService.new(value: 5)
    result = service.call
    
    assert_equal 10, result
    assert service.success?
    assert_not service.errors?
    assert_equal "Operation completed successfully", service.notice
  end
  
  test "service with errors returns failure" do
    service = FailingService.new
    service.call
    
    assert service.errors?
    assert_not service.success?
    assert_includes service.errors.full_messages, "Something went wrong\nAnother error occurred"
  end
  
  test "service can be called with class method" do
    # Call returns the result of process method
    result = SuccessfulService.call(value: 3)
    assert_equal 6, result  # 3 * 2
    
    # To check success, use the block pattern
    SuccessfulService.call(value: 3) do |service,**options|
      # First param is a hash with :noticable key containing the NoticableRuntime
      assert options[:noticable].success?
    end
  end
  
  test "service with validation errors drops execution" do
    service = ValidatedService.new(email: "")
    service.call
    
    assert service.errors?
    assert_includes service.errors.full_messages, "Email cannot be blank"
  end
  
  test "service with valid data processes successfully" do
    service = ValidatedService.new(email: "test@example.com")
    result = service.call
    
    assert service.success?
    assert_equal "Email is valid: test@example.com", result
  end
  
  test "service callbacks are executed" do
    service = CallbackService.new
    service.call
    
    assert service.setup_called
    assert service.cleanup_called
  end
  
  test "service with exception can be rescued with block" do
    service = ExceptionService.new
    rescued = false
    
    service.call do |service,**options|
      # The block receives a hash with :noticable key containing the NoticableRuntime
      rescued = true if options[:noticable].errors?
    end
    
    assert rescued
    assert service.errors?
  end
  
  test "service wraps process in transaction by default" do
    # This would need actual AR models to test properly
    # Placeholder for transaction testing
    assert Steroids::Services::Base.class_variable_get(:@@wrap_in_transaction)
  end
  
  test "drop! halts execution" do
    class DroppingService < Steroids::Services::Base
      attr_reader :after_drop_called
      
      def initialize
        @after_drop_called = false
      end
      
      def process
        drop!("Critical error")
        @after_drop_called = true  # Should not be reached
      end
    end
    
    service = DroppingService.new
    service.call
    
    assert_not service.after_drop_called
    assert service.errors?
  end
end
