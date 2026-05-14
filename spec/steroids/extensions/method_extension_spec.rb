# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::MethodExtension do
  let(:target_class) do
    Class.new do
      def zero_arg = "z"
      def one_arg(arg) = "1:#{arg}"
      def with_kwarg(arg, key:) = "k:#{arg}/#{key}"
      def with_keyrest(**opts) = "rest:#{opts.keys.sort.join(',')}"
      def with_rest(*args) = "splat:#{args.size}"
    end
  end

  let(:target) { target_class.new }

  describe "#arguments" do
    it "lists positional parameter names" do
      expect(target.method(:one_arg).arguments).to eq([:arg])
      expect(target.method(:with_kwarg).arguments).to eq([:arg])
    end
  end

  describe "#options" do
    it "lists keyword parameter names" do
      expect(target.method(:with_kwarg).options).to eq([:key])
    end
  end

  describe "#spread? / #rest?" do
    it "detects **opts (keyrest)" do
      expect(target.method(:with_keyrest)).to be_spread
      expect(target.method(:with_kwarg)).not_to be_spread
    end

    it "detects *args (rest)" do
      expect(target.method(:with_rest)).to be_rest
      expect(target.method(:one_arg)).not_to be_rest
    end
  end

  describe "#apply" do
    it "trims extra positionals for fixed-arity methods" do
      expect(target.method(:one_arg).apply("hello", "ignored")).to eq("1:hello")
    end

    it "does not crash when given kwargs against a zero-arg method" do
      expect(target.method(:zero_arg).apply(extra: 1)).to eq("z")
    end

    it "passes all positionals when method has *rest" do
      expect(target.method(:with_rest).apply(1, 2, 3)).to eq("splat:3")
    end

    it "forwards only declared keyword args" do
      expect(target.method(:with_kwarg).apply("hello", key: "world", extra: "dropped"))
        .to eq("k:hello/world")
    end

    it "forwards all keyword args when method has **keyrest" do
      expect(target.method(:with_keyrest).apply(a: 1, b: 2, c: 3)).to eq("rest:a,b,c")
    end

    it "is also available on Procs (ProcExtension)" do
      p = ->(a, b) { "#{a}-#{b}" }
      expect(p.apply("x", "y", "z")).to eq("x-y")
    end
  end
end
