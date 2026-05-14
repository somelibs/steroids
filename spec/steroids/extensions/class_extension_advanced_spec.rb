# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ClassExtension, "advanced helpers" do
  describe "#freeze" do
    it "forces attribute defaults to materialize before freezing" do
      klass = Class.new do
        attribute :slug, default: "frozen-default"
      end
      instance = klass.new
      instance.freeze
      expect(instance.slug).to eq("frozen-default")
      expect(instance).to be_frozen
    end
  end

  describe "#forward_methods_to" do
    it "delegates any matching method via respond_to handler" do
      target = Class.new do
        def perform_step1 = "step1"
        def perform_step2 = "step2"
        def can_handle?(name) = name.to_s.start_with?("perform_")

        forward_methods_to :can_handle?, if: :can_handle?
      end
      instance = target.new
      expect(instance.respond_to?(:perform_step1)).to be true
      expect(instance.respond_to?(:unknown_method)).to be false
    end
  end

  describe "#try_delegate" do
    it "delegates when the target responds to the method, otherwise raises NoMethodError" do
      inner = Class.new { def greet = "hi" }
      outer = Class.new do
        attr_accessor :inner

        try_delegate :greet, to: :inner
      end
      instance = outer.new
      instance.inner = inner.new
      expect(instance.greet).to eq("hi")
    end

    it "falls through to super when the delegate is missing" do
      outer = Class.new do
        attr_accessor :inner

        try_delegate :greet, to: :inner
      end
      instance = outer.new
      instance.inner = nil
      expect { instance.greet }.to raise_error(NoMethodError)
    end
  end

  describe "#runtime_methods / #runtime_instance_methods" do
    it "returns methods relative to Object" do
      klass = Class.new do
        def self.example_singleton; end
        def example_instance; end
      end
      expect(klass.runtime_methods).to include(:example_singleton)
      expect(klass.runtime_instance_methods).to include(:example_instance)
    end
  end
end
