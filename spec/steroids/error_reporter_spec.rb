# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::ErrorReporter do
  let(:subscriber) do
    Class.new do
      attr_reader :reports

      def initialize
        @reports = []
      end

      def report(error, handled:, severity: :error, context: {}, source: nil)
        @reports << { error: error, handled: handled, context: context, severity: severity, source: source }
      end
    end.new
  end

  before { Rails.error.subscribe(subscriber) if Rails.error.respond_to?(:subscribe) }
  after  { Rails.error.unsubscribe(subscriber) if Rails.error.respond_to?(:unsubscribe) }

  describe ".report_once!" do
    it "delivers handled=true to Rails.error subscribers with context" do
      error = StandardError.new("boom")

      expect(described_class.report_once!(error, service: "BoomService")).to be true

      expect(subscriber.reports.size).to eq(1)
      report = subscriber.reports.first
      expect(report[:error]).to eq(error)
      expect(report[:handled]).to be true
      expect(report[:context][:service]).to eq("BoomService")
    end

    it "is idempotent — second call on the same exception is a no-op" do
      error = StandardError.new("boom")

      expect(described_class.report_once!(error)).to be true
      expect(described_class.report_once!(error)).to be false
      expect(described_class.report_once!(error)).to be false

      expect(subscriber.reports.size).to eq(1)
    end

    it "delivers each distinct exception once" do
      error1 = StandardError.new("first")
      error2 = StandardError.new("second")

      described_class.report_once!(error1)
      described_class.report_once!(error2)
      described_class.report_once!(error1)

      expect(subscriber.reports.size).to eq(2)
    end

    it "ignores non-Exception arguments rather than crashing" do
      expect(described_class.report_once!("a string")).to be false
      expect(described_class.report_once!(nil)).to be false
      expect(subscriber.reports).to be_empty
    end

    it "never raises even if a subscriber blows up" do
      blowup = Class.new do
        def report(*)
          raise "subscriber down"
        end
      end.new
      Rails.error.subscribe(blowup)
      error = StandardError.new("boom")

      expect { described_class.report_once!(error) }.not_to raise_error
    ensure
      Rails.error.unsubscribe(blowup)
    end
  end

  describe ".reported? / .mark_reported!" do
    it "reflects the dedup flag" do
      error = StandardError.new("boom")

      expect(described_class.reported?(error)).to be false
      described_class.mark_reported!(error)
      expect(described_class.reported?(error)).to be true
    end
  end
end
