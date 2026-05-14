# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Logger do
  let(:captured) { StringIO.new }
  let(:original_logger) { Rails.logger }

  before { Rails.logger = ::Logger.new(captured) }
  after  { Rails.logger = original_logger }

  describe ".print" do
    it "returns true for plain inputs" do
      expect(described_class.print("hello")).to be true
    end

    it "returns true for unlogged exceptions" do
      expect(described_class.print(StandardError.new("boom"))).to be true
    end

    it "returns false for Steroids errors that have already been logged" do
      error = Steroids::Errors::BadRequestError.new(message: "x", log: true)
      expect(described_class.print(error)).to be false
    end
  end

  describe "level inference" do
    it "logs plain strings at :info" do
      described_class.print("a plain message")
      expect(captured.string).to match(/INFO/)
    end

    it "logs non-internal Steroids errors at :warn" do
      described_class.print(Steroids::Errors::BadRequestError.new(message: "bad"))
      expect(captured.string).to match(/WARN/)
    end

    it "logs InternalServerError at :error" do
      described_class.print(Steroids::Errors::InternalServerError.new(message: "kaboom"))
      expect(captured.string).to match(/ERROR/)
    end

    it "logs raw exceptions at :error" do
      described_class.print(StandardError.new("raw"))
      expect(captured.string).to match(/ERROR/)
    end
  end

  describe "notifier" do
    around do |example|
      example.run
    ensure
      described_class.notifier = false
    end

    it "fires for error-level exceptions" do
      seen = []
      described_class.notifier = ->(exc) { seen << exc }
      err = StandardError.new("call-the-notifier")

      described_class.print(err)
      expect(seen).to eq([err])
    end

    it "does not fire for non-exception, info-level inputs" do
      seen = []
      described_class.notifier = ->(exc) { seen << exc }

      described_class.print("info only")
      expect(seen).to be_empty
    end
  end
end
