# frozen_string_literal: true

# ------------------------------------------------------------------------------------------------
# Steroids::ErrorReporter
# ------------------------------------------------------------------------------------------------
# Thin agnostic seam for reporting *handled* exceptions to whatever observability
# tool the parent application has wired up.
#
# Steroids itself stays unaware of any specific tool (AppSignal, Sentry,
# Honeybadger, ...). It delegates to `Rails.error.report` — Rails' built-in
# unified error reporter — and any subscriber the parent app has registered
# (or that an APM gem has auto-registered) will receive the report.
#
# When `Rails.error` is unavailable (older Rails, non-Rails context), this
# module degrades to a no-op so Steroids services keep working without an
# observability layer in place.
#
# Idempotent: each exception is reported at most once. Marker is stored on
# the exception object itself, so callers higher in the stack (e.g. a
# controller rescue) can safely call `report_once!` again without producing
# duplicate events in the dashboard.
# ------------------------------------------------------------------------------------------------
module Steroids
  module ErrorReporter
    REPORTED_FLAG = :@_steroids_reported

    # Report `exception` exactly once with optional context tags.
    # Returns true if a report was emitted, false if it was suppressed
    # (already reported, or no observability layer available).
    def self.report_once!(exception, **context)
      return false unless exception.is_a?(Exception)
      return false if reported?(exception)

      mark_reported!(exception)
      deliver(exception, context)
    end

    # Has this exception already been reported through this seam?
    def self.reported?(exception)
      exception.instance_variable_defined?(REPORTED_FLAG) &&
        exception.instance_variable_get(REPORTED_FLAG) == true
    end

    def self.mark_reported!(exception)
      exception.instance_variable_set(REPORTED_FLAG, true)
    end

    def self.deliver(exception, context)
      return false unless defined?(Rails) && Rails.respond_to?(:error)

      reporter = Rails.error
      return false unless reporter.respond_to?(:report)

      reporter.report(exception, handled: true, context: context)
      true
    rescue StandardError => delivery_error
      # Never let the observability seam itself raise. Best-effort log and
      # swallow so the calling code's existing rescue path is not disturbed.
      warn "[Steroids::ErrorReporter] delivery failed: " \
           "#{delivery_error.class}: #{delivery_error.message}"
      false
    end
  end
end
