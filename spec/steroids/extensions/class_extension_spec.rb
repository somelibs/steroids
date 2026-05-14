# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ClassExtension do
  describe "#attribute" do
    it "defines a reader and a writer" do
      klass = Class.new do
        attribute :name, default: "anon", type: "String"
      end

      instance = klass.new
      expect(instance.name).to eq("anon")
      instance.name = "Ada"
      expect(instance.name).to eq("Ada")
    end

    it "enforces the declared type via typed!" do
      klass = Class.new do
        attribute :count, default: 0, type: "Integer"
      end
      expect { klass.new.count = "not-an-int" }.to raise_error(TypeError)
    end

    it "allows nil when allow_nil is true" do
      klass = Class.new do
        attribute :tag, type: "String", allow_nil: true
      end
      instance = klass.new
      expect { instance.tag = nil }.not_to raise_error
      expect(instance.tag).to be_nil
    end

    it "tracks declared attributes on the class" do
      klass = Class.new do
        attribute :a
        attribute :b
      end
      expect(klass.steroids_attributes_set).to eq([:a, :b])
    end
  end

  describe "#delegate_alias" do
    it "forwards through send_apply with an alias" do
      inner_class = Class.new { def shout(msg) = msg.upcase }
      outer_class = Class.new do
        attr_accessor :backend

        delegate_alias :yell, to: :backend, method: :shout
      end

      outer = outer_class.new
      outer.backend = inner_class.new
      expect(outer.yell("hello")).to eq("HELLO")
    end
  end

  describe ".build_anonymous" do
    it "returns an anonymous class with the demodulized name" do
      parent = Class.new
      klass = Class.build_anonymous("Built", parent) { def hello = :hi }
      expect(klass.name).to eq("Built")
      expect(klass).to be_anonymous
      expect(klass.new.hello).to eq(:hi)
    ensure
      Object.send(:remove_const, :Built) if defined?(::Built)
    end
  end
end
