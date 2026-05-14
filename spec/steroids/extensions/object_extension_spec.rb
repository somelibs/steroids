# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ObjectExtension do
  describe "#typed / #typed!" do
    it "returns self when the class matches" do
      expect("foo".typed(String)).to eq("foo")
      expect(42.typed(Integer)).to eq(42)
    end

    it "returns nil when the class does not match" do
      expect("foo".typed(Integer)).to be_nil
      expect(42.typed(String)).to be_nil
    end

    it "typed! returns self when the class matches" do
      expect("foo".typed!(String)).to eq("foo")
    end

    it "typed! raises TypeError when the class does not match" do
      expect { "foo".typed!(Integer) }
        .to raise_error(TypeError, /Expected .* to be an instance of Integer/)
    end

    it "passes nil through" do
      expect(nil.typed(String)).to be_nil
      expect(nil.typed!(String)).to be_nil
    end
  end

  describe "#boolean?" do
    it "is true only for true/false" do
      expect(true.boolean?).to be true
      expect(false.boolean?).to be true
      expect(nil.boolean?).to be false
      expect("true".boolean?).to be false
      expect(1.boolean?).to be false
      expect(0.boolean?).to be false
    end
  end

  describe "#ifnil" do
    it "returns self when not nil" do
      expect("value".ifnil("default")).to eq("value")
      expect(0.ifnil("default")).to eq(0)
    end

    it "returns the default when nil" do
      expect(nil.ifnil("default")).to eq("default")
    end
  end

  describe "#try_method" do
    it "returns a Method when responded to" do
      method_obj = "hello".try_method(:upcase)
      expect(method_obj).to be_a(Method)
      expect(method_obj.call).to eq("HELLO")
    end

    it "returns nil when the method is missing" do
      expect("hello".try_method(:no_such_method)).to be_nil
    end

    it "finds private methods" do
      klass = Class.new do
        private def secret = "shh"
      end
      expect(klass.new.try_method(:secret)).to be_a(Method)
    end
  end

  describe "#send_apply / #send_apply!" do
    it "calls existing methods" do
      expect("hello".send_apply(:upcase)).to eq("HELLO")
    end

    it "returns nil for missing methods (does not raise)" do
      expect("hello".send_apply(:no_such_method)).to be_nil
    end

    it "trims extra arguments to fit method arity" do
      target = Object.new
      target.define_singleton_method(:greet) { |name| "Hello, #{name}" }
      expect(target.send_apply(:greet, "Ada", "extra", junk: true)).to eq("Hello, Ada")
    end

    it "works for zero-arg methods called with extras" do
      target = Object.new
      target.define_singleton_method(:zero_arg) { "ok" }
      expect(target.send_apply(:zero_arg, "ignored", k: 1)).to eq("ok")
    end

    it "send_apply! returns NoMethodError instance instead of raising on missing method" do
      result = "hello".send_apply!(:no_such_method)
      expect(result).to be_a(NoMethodError)
    end
  end

  describe "#instance_apply" do
    it "runs the block in the object context with matched args" do
      target = Object.new
      target.define_singleton_method(:label) { "T" }

      result = target.instance_apply("a", "b", "c") do |first|
        "#{label}: #{first}"
      end

      expect(result).to eq("T: a")
    end

    it "is a no-op when no block is given" do
      expect(Object.new.instance_apply("a")).to be_nil
    end
  end

  describe "#marshallable?" do
    it "is true for primitives and serializable structures" do
      expect("string".marshallable?).to be true
      expect(42.marshallable?).to be true
      expect({ a: 1, b: [2, 3] }.marshallable?).to be true
    end

    it "is false for unmarshallable values" do
      expect(->(x) { x }.marshallable?).to be false
      expect($stdout.marshallable?).to be false
    end
  end

  describe "#serializable? / #deep_serialize" do
    it "is true for nested primitives" do
      expect("str".serializable?).to be true
      expect(1.serializable?).to be true
      expect(true.serializable?).to be true
      expect(nil.serializable?).to be true
      expect(:sym.serializable?).to be true
      expect([1, "two", :three].serializable?).to be true
      expect({ a: 1, b: { c: [1, 2] } }.serializable?).to be true
    end

    it "deep_serialize recurses into Hashes and Arrays" do
      input = { a: 1, b: [{ c: :sym }, 2] }
      expect(input.deep_serialize).to eq(a: 1, b: [{ c: :sym }, 2])
    end

    it "deep_serialize raises for unserializable leaves when include_object=false" do
      expect { { proc: ->(x) { x } }.deep_serialize(false) }.to raise_error(TypeError)
    end
  end
end
