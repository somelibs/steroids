require "test_helper"

# Steroids::Logger wraps Rails.logger with rainbow-colorized formatting.
# These tests exercise the public `.print` surface and the level inference.
class LoggerTest < ActiveSupport::TestCase
  setup do
    @captured = StringIO.new
    @original = Rails.logger
    Rails.logger = ::Logger.new(@captured)
  end

  teardown { Rails.logger = @original }

  test ".print returns true for plain inputs" do
    assert_equal true, Steroids::Logger.print("hello")
  end

  test ".print returns true for unlogged exceptions" do
    assert_equal true, Steroids::Logger.print(StandardError.new("boom"))
  end

  test ".print returns false for Steroids errors that have already been logged" do
    # Steroids::Errors::Base#initialize already logs once (via `log!` or `quiet_log`),
    # marking @logged = true on the instance. A second .print should bail.
    error = Steroids::Errors::BadRequestError.new(message: "x", log: true)
    assert_equal false, Steroids::Logger.print(error)
  end

  test "plain inputs land in Rails.logger at :info level" do
    Steroids::Logger.print("a plain message")
    assert_match(/INFO/, @captured.string)
  end

  test "Steroids::Errors::Base subclasses (non-Internal) log at :warn" do
    err = Steroids::Errors::BadRequestError.new(message: "bad")
    # Logger.print is wrapped here directly to avoid re-using the cached @logged state.
    Steroids::Logger.print(err)
    assert_match(/WARN/, @captured.string)
  end

  test "InternalServerError logs at :error" do
    err = Steroids::Errors::InternalServerError.new(message: "kaboom")
    Steroids::Logger.print(err)
    assert_match(/ERROR/, @captured.string)
  end

  test "non-Steroids exception falls back to :error level" do
    Steroids::Logger.print(StandardError.new("raw"))
    assert_match(/ERROR/, @captured.string)
  end

  test "notifier callback fires for error-level exceptions" do
    seen = []
    Steroids::Logger.notifier = ->(exc) { seen << exc }

    err = StandardError.new("call-the-notifier")
    Steroids::Logger.print(err)
    assert_equal [err], seen
  ensure
    Steroids::Logger.notifier = false
  end

  test "notifier callback does NOT fire for non-exception, info-level inputs" do
    seen = []
    Steroids::Logger.notifier = ->(exc) { seen << exc }

    Steroids::Logger.print("info only")
    assert_empty seen
  ensure
    Steroids::Logger.notifier = false
  end
end
