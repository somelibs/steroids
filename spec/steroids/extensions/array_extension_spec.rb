# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ArrayExtension do
  describe "#cast" do
    it "returns the matching element" do
      expect([:draft, :published, :archived].cast(:draft)).to eq(:draft)
      expect(["a", "b"].cast("a")).to eq("a")
    end

    it "raises ElementNotFound when the value is missing" do
      expect { [:draft, :published].cast(:unknown) }
        .to raise_error(Steroids::Extensions::ArrayExtension::ElementNotFound, /Cast: Element not found/)
    end

    it "matches across symbol/string when indifferent_access is true" do
      expect([:draft, :published].cast("draft", true)).to eq(:draft)
    end

    it "is strict by default (string vs symbol mismatch raises)" do
      expect { [:draft, :published].cast("draft") }
        .to raise_error(Steroids::Extensions::ArrayExtension::ElementNotFound)
    end
  end

  describe "#find_map" do
    it "returns the first truthy block result" do
      expect([1, 2, 3, 4].find_map { |n| n.even? ? "even:#{n}" : nil }).to eq("even:2")
    end

    it "returns nil when no element yields a truthy value" do
      expect([1, 3, 5].find_map { |n| n.even? ? n : nil }).to be_nil
    end

    it "returns an Enumerator when called without a block" do
      expect([1, 2, 3].find_map).to be_a(Enumerator)
    end

    it "short-circuits — does not call block past first hit" do
      calls = []
      [1, 2, 3, 4].find_map do |n|
        calls << n
        n == 2 ? "stop" : nil
      end
      expect(calls).to eq([1, 2])
    end
  end
end
