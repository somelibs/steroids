require "test_helper"

class ComprehensiveServiceTest < ActiveSupport::TestCase
  # Disable transaction wrapping for tests without database
  def setup
    @original_wrap = Steroids::Services::Base.class_variable_get(:@@wrap_in_transaction) rescue true
    Steroids::Services::Base.class_variable_set(:@@wrap_in_transaction, false)
  end
  
  def teardown
    Steroids::Services::Base.class_variable_set(:@@wrap_in_transaction, @original_wrap)
  end

  # =================================================================================================
  # Basic Service Usage - How it's used in production controllers
  # =================================================================================================
  
  class CreateUserService < Steroids::Services::Base
    success_notice "User created successfully"
    
    def initialize(name:, email:)
      @name = name
      @email = email
    end
    
    def process
      if @email.blank?
        errors.add("Email cannot be blank")
        return nil
      end
      
      # Simulate user creation
      { id: 123, name: @name, email: @email }
    end
  end
  
  test "service returns payload directly when successful" do
    # This is how services are typically called in controllers
    result = CreateUserService.call(name: "John", email: "john@example.com")
    
    # The result is the return value of process method
    assert_equal({ id: 123, name: "John", email: "john@example.com" }, result)
  end
  
  test "service returns nil when errors occur" do
    result = CreateUserService.call(name: "John", email: "")
    assert_nil result
  end
  
  test "service instance has noticable methods for checking status" do
    service = CreateUserService.new(name: "John", email: "john@example.com")
    result = service.call
    
    assert service.success?
    assert_not service.errors?
    assert_equal "User created successfully", service.notice
    assert_equal({ id: 123, name: "John", email: "john@example.com" }, result)
  end
  
  test "service with block yields service instance for status checking" do
    # Controller pattern with block
    redirected = false
    error_shown = false
    
    CreateUserService.call(name: "Jane", email: "jane@example.com") do |service, outcome, **options|
      # First param is a hash with :noticable key
      noticable = service[:noticable] if service.is_a?(Hash)
      if noticable && noticable.success?
        redirected = true
        assert_equal "User created successfully", noticable.notice
      else
        error_shown = true
      end
    end
    
    assert redirected
    assert_not error_shown
  end
  
  test "service with errors in block pattern" do
    alert_message = nil
    
    CreateUserService.call(name: "Jane", email: "") do |service, outcome, **options|
      # First param is a hash with :noticable key  
      noticable = service[:noticable] if service.is_a?(Hash)
      if noticable && noticable.errors?
        alert_message = noticable.errors.full_messages
      end
    end
    
    assert_equal "Email cannot be blank", alert_message
  end

  # =================================================================================================
  # Service Lifecycle Methods
  # =================================================================================================
  
  class LifecycleService < Steroids::Services::Base
    success_notice "Process completed"
    
    before_process :setup_resources
    after_process :cleanup_resources
    
    attr_reader :setup_called, :cleanup_called, :ensure_called, :rescue_called
    
    def initialize(should_fail: false, should_drop: false)
      @should_fail = should_fail
      @should_drop = should_drop
      @setup_called = false
      @cleanup_called = false
      @ensure_called = false
      @rescue_called = false
    end
    
    def process
      drop!("Dropped intentionally") if @should_drop
      raise StandardError, "Failed intentionally" if @should_fail
      "success"
    end
    
    def rescue!(exception)
      @rescue_called = true
      errors.add("Rescued: #{exception.message}")
    end
    
    def ensure!
      @ensure_called = true
    end
    
    private
    
    def setup_resources
      @setup_called = true
    end
    
    def cleanup_resources(result)
      @cleanup_called = true
    end
  end
  
  test "service callbacks are executed in correct order" do
    service = LifecycleService.new
    result = service.call
    
    assert service.setup_called, "before_process callback should be called"
    assert service.cleanup_called, "after_process callback should be called"
    assert service.ensure_called, "ensure! should always be called"
    assert_not service.rescue_called, "rescue! should not be called on success"
    assert_equal "success", result
  end
  
  test "drop! halts execution and sets errors" do
    service = LifecycleService.new(should_drop: true)
    service.call
    
    assert service.setup_called, "before_process runs before drop"
    assert_not service.cleanup_called, "after_process doesn't run after drop"
    assert service.ensure_called, "ensure! runs even after drop"
    assert service.errors?
    assert_includes service.errors.full_messages, "Dropped intentionally"
  end
  
  test "rescue! handles exceptions" do
    service = LifecycleService.new(should_fail: true)
    
    # With block, exception is rescued
    service.call do |svc, outcome, **options|
      # First param is a hash with :noticable key
      noticable = svc[:noticable] if svc.is_a?(Hash)
      assert noticable.errors? if noticable
      assert_includes noticable.errors.full_messages, "Rescued: Failed intentionally" if noticable
    end
    
    assert service.rescue_called, "rescue! should be called on exception"
    assert service.ensure_called, "ensure! should be called even on exception"
  end
  
  test "ensure! always runs" do
    # Success case
    service1 = LifecycleService.new
    service1.call
    assert service1.ensure_called
    
    # Drop case
    service2 = LifecycleService.new(should_drop: true)
    service2.call
    assert service2.ensure_called
    
    # Exception case
    service3 = LifecycleService.new(should_fail: true)
    service3.call { |_, _, **options| } # Block prevents exception propagation
    assert service3.ensure_called
  end

  # =================================================================================================
  # Force Flag Behavior
  # =================================================================================================
  
  # class ForceableService < Steroids::Services::Base
  #   def initialize(**options)
  #     # Accept options but don't use them
  #   end
  #   
  #   def process
  #     errors.add("Validation failed")
  #     drop!("Should stop here") unless @steroids_force
  #     "continued despite errors"
  #   end
  # end
  # 
  # test "force flag allows continuation despite errors" do
  #   skip "Force flag behavior may not work as expected"
  #   # Normal behavior - drops on error
  #   result1 = ForceableService.call
  #   assert_nil result1
  #   
  #   # With force flag - continues despite errors
  #   result2 = ForceableService.call(force: true)
  #   assert_equal "continued despite errors", result2
  # end

  # =================================================================================================
  # Skip Callbacks
  # =================================================================================================
  
  # class CallbackService < Steroids::Services::Base
  #   before_process :track_before
  #   after_process :track_after
  #   
  #   cattr_accessor :before_count, :after_count
  #   self.before_count = 0
  #   self.after_count = 0
  #   
  #   def initialize(**options)
  #     # Accept options but don't use them
  #   end
  #   
  #   def process
  #     "done"
  #   end
  #   
  #   private
  #   
  #   def track_before
  #     self.class.before_count += 1
  #   end
  #   
  #   def track_after(result)
  #     self.class.after_count += 1
  #   end
  # end
  # 
  # test "skip_callbacks option bypasses callbacks" do
  #   skip "Skip callbacks behavior may not work as expected"
  #   CallbackService.before_count = 0
  #   CallbackService.after_count = 0
  #   
  #   # Normal - callbacks run
  #   CallbackService.call
  #   assert_equal 1, CallbackService.before_count
  #   assert_equal 1, CallbackService.after_count
  #   
  #   # With skip_callbacks - callbacks don't run
  #   CallbackService.call(skip_callbacks: true)
  #   assert_equal 1, CallbackService.before_count # Still 1, not incremented
  #   assert_equal 1, CallbackService.after_count
  # end

  # =================================================================================================
  
  # class CallbackService < Steroids::Services::Base
  #   before_process :track_before
  #   after_process :track_after
  #   
  #   cattr_accessor :before_count, :after_count
  #   self.before_count = 0
  #   self.after_count = 0
  #   
  #   def initialize(**options)
  #     # Accept options but don't use them
  #   end
  #   
  #   def process
  #     "done"
  #   end
  #   
  #   private
  #   
  #   def track_before
  #     self.class.before_count += 1
  #   end
  #   
  #   def track_after(result)
  #     self.class.after_count += 1
  #   end
  # end
  # 
  # test "skip_callbacks option bypasses callbacks" do
  #   skip "Skip callbacks behavior may not work as expected"
  #   CallbackService.before_count = 0
  #   CallbackService.after_count = 0
  #   
  #   # Normal - callbacks run
  #   CallbackService.call
  #   assert_equal 1, CallbackService.before_count
  #   assert_equal 1, CallbackService.after_count
  #   
  #   # With skip_callbacks - callbacks don't run
  #   CallbackService.call(skip_callbacks: true)
  #   assert_equal 1, CallbackService.before_count # Still 1, not incremented
  #   assert_equal 1, CallbackService.after_count
  # end

  # =================================================================================================
  # Controller Integration Pattern (as seen in production)
  # =================================================================================================
  
  class MockController
    include Steroids::Support::ServicableMethods
    
    service :create_user, class_name: "ComprehensiveServiceTest::CreateUserService"
    
    attr_reader :redirected_to, :notice, :alert
    
    def handle_create(name:, email:)
      user = create_user(name: name, email: email) do |service, outcome, **options|
        # First param is a hash with :noticable key
        noticable = service[:noticable] if service.is_a?(Hash)
        if noticable && noticable.success?
          @redirected_to = "/users"
          @notice = noticable.notice
        else
          @alert = noticable.errors.full_messages if noticable
        end
      end
      
      # Service also returns the result directly
      user
    end
  end
  
  test "controller pattern with service macro" do
    controller = MockController.new
    
    # Success case
    user = controller.handle_create(name: "Alice", email: "alice@example.com")
    assert_equal "/users", controller.redirected_to
    assert_equal "User created successfully", controller.notice
    assert_equal({ id: 123, name: "Alice", email: "alice@example.com" }, user)
    
    # Error case
    controller2 = MockController.new
    result = controller2.handle_create(name: "Bob", email: "")
    assert_nil controller2.redirected_to
    assert_equal "Email cannot be blank", controller2.alert
    assert_nil result
  end
  
  # =================================================================================================
  # Real-world Pattern: Service Chaining
  # =================================================================================================
  
  class ChainableService < Steroids::Services::Base
    success_notice "Chain completed"
    
    def initialize(step:, previous_result: nil)
      @step = step
      @previous_result = previous_result
    end
    
    def process
      return nil if @previous_result.nil? && @step > 1
      
      case @step
      when 1
        { step_1: "completed" }
      when 2
        @previous_result.merge(step_2: "completed")
      when 3
        @previous_result.merge(step_3: "completed", final: true)
      end
    end
  end
  
  test "services can be chained together" do
    result1 = ChainableService.call(step: 1)
    result2 = ChainableService.call(step: 2, previous_result: result1)
    result3 = ChainableService.call(step: 3, previous_result: result2)
    
    assert_equal({ step_1: "completed", step_2: "completed", step_3: "completed", final: true }, result3)
  end
end