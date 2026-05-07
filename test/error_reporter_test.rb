require "test_helper"

class ErrorReporterTest < ActiveSupport::TestCase
  # ------------------------------------------------------------------
  # Test reporter that records every report it receives. Stands in for
  # whatever observability subscriber a parent app would have wired up
  # (AppSignal, Sentry, ...) — Steroids itself stays unaware of the tool.
  # ------------------------------------------------------------------
  class RecordingSubscriber
    def initialize
      @reports = []
    end

    def report(error, handled:, severity: :error, context: {}, source: nil)
      @reports << { error: error, handled: handled, context: context, severity: severity, source: source }
    end

    attr_reader :reports
  end

  def setup
    @subscriber = RecordingSubscriber.new
    Rails.error.subscribe(@subscriber) if Rails.error.respond_to?(:subscribe)
  end

  def teardown
    Rails.error.unsubscribe(@subscriber) if Rails.error.respond_to?(:unsubscribe)
  end

  test "report_once! delivers handled=true to Rails.error subscribers with context" do
    error = StandardError.new("boom")

    assert Steroids::ErrorReporter.report_once!(error, service: "BoomService")

    assert_equal 1, @subscriber.reports.size
    report = @subscriber.reports.first
    assert_equal error, report[:error]
    assert_equal true, report[:handled]
    assert_equal "BoomService", report[:context][:service]
  end

  test "report_once! is idempotent — second call on the same exception is a no-op" do
    error = StandardError.new("boom")

    assert Steroids::ErrorReporter.report_once!(error, service: "BoomService")
    refute Steroids::ErrorReporter.report_once!(error, service: "BoomService")
    refute Steroids::ErrorReporter.report_once!(error, service: "BoomService")

    assert_equal 1, @subscriber.reports.size
  end

  test "report_once! across distinct exceptions delivers each once" do
    error1 = StandardError.new("first")
    error2 = StandardError.new("second")

    Steroids::ErrorReporter.report_once!(error1)
    Steroids::ErrorReporter.report_once!(error2)
    Steroids::ErrorReporter.report_once!(error1) # already reported, suppressed

    assert_equal 2, @subscriber.reports.size
  end

  test "reported? reflects the dedup flag set by mark_reported!" do
    error = StandardError.new("boom")

    refute Steroids::ErrorReporter.reported?(error)
    Steroids::ErrorReporter.mark_reported!(error)
    assert Steroids::ErrorReporter.reported?(error)
  end

  test "report_once! ignores non-Exception arguments rather than crashing" do
    refute Steroids::ErrorReporter.report_once!("a string")
    refute Steroids::ErrorReporter.report_once!(nil)
    assert_empty @subscriber.reports
  end

  test "delivery never raises even if a subscriber blows up" do
    blowup = Class.new do
      def report(*)
        raise "subscriber down"
      end
    end.new
    Rails.error.subscribe(blowup)
    error = StandardError.new("boom")

    # Should not raise — ErrorReporter swallows subscriber failures.
    assert_nothing_raised do
      Steroids::ErrorReporter.report_once!(error)
    end
  ensure
    Rails.error.unsubscribe(blowup)
  end
end
