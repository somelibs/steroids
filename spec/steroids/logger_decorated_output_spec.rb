# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Logger, "decorated output paths" do
  let(:captured) { StringIO.new }
  let(:original) { Rails.logger }

  before { Rails.logger = ::Logger.new(captured) }
  after  { Rails.logger = original }

  it "includes the cause information in the decorated output" do
    inner = StandardError.new("inner cause")
    wrapped = begin
      begin
        raise inner
      rescue => e
        raise Steroids::Errors::BadRequestError.new(message: "outer", cause: e)
      end
    rescue Steroids::Errors::BadRequestError => e
      e
    end

    described_class.print(wrapped, verbosity: :full)
    expect(captured.string).to match(/Cause: StandardError/)
    expect(captured.string).to match(/inner cause/)
  end

  it "formats a non-exception input with a decorated header" do
    described_class.print("decorated message", format: :decorated)
    expect(captured.string).to match(/Steroids::Logger/)
    expect(captured.string).to match(/decorated message/)
  end

  it "formats with :raw format without the decorated header" do
    described_class.print("raw message", format: :raw)
    expect(captured.string).to match(/raw message/)
    expect(captured.string).not_to match(/Steroids::Logger.*--.*info/)
  end

  it "guards format_backtrace when @backtrace is nil (unraised exception)" do
    exc = StandardError.new("unraised") # backtrace is nil
    expect { described_class.print(exc, verbosity: :full) }.not_to raise_error
  end
end
