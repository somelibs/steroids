# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Errors::Quotes do
  let(:host_class) do
    Class.new(Steroids::Errors::Base)
  end

  describe "#quote" do
    it "returns a string from the quotes file" do
      Rails.cache.delete("steroids/quotes")
      quote = host_class.new("msg").send(:quote)
      expect(quote).to be_a(String).or be_nil
    end

    it "falls back to a stub when the file load fails" do
      Rails.cache.delete("steroids/quotes")
      allow(YAML).to receive(:load_file).and_raise(Errno::ENOENT)
      quote = host_class.new("msg").send(:quote)
      expect(["One little bug...", nil]).to include(quote)
    ensure
      Rails.cache.delete("steroids/quotes")
    end
  end
end
