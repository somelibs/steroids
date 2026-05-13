require "test_helper"

class BaseErrorTest < ActiveSupport::TestCase
  # Custom error for testing
  class CustomTestError < Steroids::Errors::Base
    self.default_message = "Custom default message"
    self.default_status = :unprocessable_content
  end

  # Custom error NOT registered in ActionDispatch::ExceptionWrapper.rescue_responses,
  # to exercise the unregistered-class fallback path in `assert_status_from_error`.
  class UnregisteredCustomError < Steroids::Errors::Base
    self.default_message = "Unregistered default message"
    self.default_status = :forbidden
  end

  # Basic error creation tests
  test "error can be created with string message" do
    error = Steroids::Errors::Base.new("Something went wrong")

    assert_equal "Something went wrong", error.message
    assert_equal :internal_server_error, error.status
  end

  test "error uses default message when none provided" do
    error = Steroids::Errors::Base.new

    assert_equal "Oops, something went wrong (Unknown error)", error.message
  end

  test "custom error uses its default message and status" do
    error = CustomTestError.new

    assert_equal "Custom default message", error.message
    assert_equal :unprocessable_content, error.status
  end

  test "error can be created with options" do
    original_error = StandardError.new("Original")

    error = Steroids::Errors::Base.new(
      message: "Custom message",
      status: :bad_request,
      cause: original_error,
      context: { user_id: 123, action: "update" }
    )

    assert_equal "Custom message", error.message
    assert_equal :bad_request, error.status
    assert_equal 520, error.code # Default code when not derived from status
    assert_equal original_error, error.cause
    assert_equal({ user_id: 123, action: "update" }, error.context)
  end

  # HTTP error classes tests
  test "BadRequestError has correct defaults" do
    error = Steroids::Errors::BadRequestError.new

    assert_equal "Request failed (BadRequestError).", error.message
    assert_equal :bad_request, error.status
  end

  test "UnauthorizedError has correct defaults" do
    error = Steroids::Errors::UnauthorizedError.new

    assert_equal "You shall not pass! (Unauthorized)", error.message
    assert_equal :unauthorized, error.status
  end

  test "ForbiddenError has correct defaults" do
    error = Steroids::Errors::ForbiddenError.new

    assert_equal "You shall not pass! (ForbiddenError)", error.message
    assert_equal :forbidden, error.status
  end

  test "NotFoundError has correct defaults" do
    error = Steroids::Errors::NotFoundError.new

    assert_equal "We couldn't find what you were looking for (NotfoundError)", error.message
    assert_equal :not_found, error.status
  end

  test "ConflictError has correct defaults" do
    error = Steroids::Errors::ConflictError.new

    assert_equal "Already exists (InternalConflictError)", error.message
    assert_equal :conflict, error.status
  end

  test "UnprocessableEntityError has correct defaults" do
    error = Steroids::Errors::UnprocessableEntityError.new

    assert_equal "We couldn't understand your request (UnprocessableEntityError)", error.message
    assert_equal :unprocessable_content, error.status
  end

  test "InternalServerError has correct defaults" do
    error = Steroids::Errors::InternalServerError.new

    assert_equal "Oops, something went wrong (InternalServerError)", error.message
    assert_equal :internal_server_error, error.status
  end

  test "NotImplementedError has correct defaults" do
    error = Steroids::Errors::NotImplementedError.new

    assert_equal "This feature hasn't been implemented yet (NotImplementedError)", error.message
    assert_equal :not_implemented, error.status
  end

  # Error serialization tests
  test "error can be serialized to JSON" do
    error = Steroids::Errors::BadRequestError.new(
      "Invalid input",
      code: "INVALID_INPUT",
      context: { field: "email" }
    )

    # to_json method exists
    assert error.respond_to?(:to_json)

    # JSON should be parseable
    json_string = error.to_json
    assert_nothing_raised do
      JSON.parse(json_string) if defined?(JSON)
    end
  end

  # Logging tests
  test "error can be logged manually" do
    error = Steroids::Errors::Base.new("Test error")

    # Should not be logged initially
    assert_nil error.logged

    # Manual logging
    error.log!
    assert error.logged
  end

  test "error auto-logs when log option is true" do
    # Suppress actual logging output for test
    Steroids::Logger.stub :print, true do
      error = Steroids::Errors::Base.new("Test error", log: true)
      assert error.logged
    end
  end

  test "error does not auto-log by default" do
    error = Steroids::Errors::Base.new("Test error")
    assert_nil error.logged
  end

  # Cause handling tests
  test "error preserves cause exception" do
    original = StandardError.new("Original error")

    begin
      raise original
    rescue => e
      error = Steroids::Errors::Base.new("Wrapped error", cause: e)

      assert_equal original, error.cause
      assert_equal "Original error", error.cause_message
    end
  end

  # Backtrace tests
  test "error captures backtrace" do
    error = Steroids::Errors::Base.new("Test error")

    assert error.backtrace
    assert error.backtrace.is_a?(Array)
  end

  test "error uses cause backtrace if available" do
    raise StandardError, "Original"
  rescue => e
    error = Steroids::Errors::Base.new("Wrapped", cause: e)

    # Should use the original error's backtrace
    assert_equal e.backtrace, error.backtrace
  end

  # Context tests
  test "error context is accessible" do
    error = Steroids::Errors::Base.new(
      "Error with context",
      context: {
        user_id: 42,
        request_id: "abc-123",
        timestamp: Time.now
      }
    )

    assert error.context
    assert_equal 42, error.context[:user_id]
    assert_equal "abc-123", error.context[:request_id]
  end

  # Error inheritance tests
  test "custom errors inherit from Base" do
    error = CustomTestError.new("Custom error")

    assert_kind_of Steroids::Errors::Base, error
    assert_kind_of StandardError, error
  end

  # Regression: `assert_status_from_error` previously used
  # `rescue_responses[name] || :internal_server_error`, but `rescue_responses`
  # is a Hash with default `:internal_server_error`, so the OR-chain in
  # `assert_status` short-circuited and `self.default_status` was never reached
  # for classes that consumer apps had not manually registered.
  test "unregistered subclass falls back to its default_status" do
    assert_not ActionDispatch::ExceptionWrapper.rescue_responses.key?(
      "BaseErrorTest::UnregisteredCustomError"
    ), "precondition: class should not be registered"

    error = UnregisteredCustomError.new

    assert_equal :forbidden, error.status
    assert_equal "Unregistered default message", error.message
  end

  test "registered class still uses the registered status" do
    error = Steroids::Errors::UnauthorizedError.new
    assert_equal :unauthorized, error.status
  end

  test "explicit status: kwarg always wins over registration and default_status" do
    error = Steroids::Errors::UnauthorizedError.new(status: :conflict)
    assert_equal :conflict, error.status
  end

  test "error can be raised and rescued" do
    assert_raises(Steroids::Errors::BadRequestError) do
      raise Steroids::Errors::BadRequestError.new("Bad request")
    end

    # Can be rescued as StandardError
    begin
      raise Steroids::Errors::NotFoundError.new("Not found")
    rescue => e
      assert_equal "Not found", e.message
      assert_instance_of Steroids::Errors::NotFoundError, e
    end
  end
end
