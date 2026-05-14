# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::HashExtension do
  describe "#fetch_any" do
    it "returns the value for the first matching key" do
      h = { a: 1, b: 2, c: 3 }
      expect(h.fetch_any(:b, :c)).to eq(2)
      expect(h.fetch_any(:a, :b, :c)).to eq(1)
    end

    it "returns the first hash-order match, not the first argument-order match" do
      h = { a: 1, b: 2 }
      expect(h.fetch_any(:b, :a)).to eq(1)
    end

    it "returns nil when no provided key matches" do
      expect({ a: 1 }.fetch_any(:b, :c)).to be_nil
    end

    it "returns nil for an empty hash" do
      expect({}.fetch_any(:a, :b)).to be_nil
    end
  end
end
