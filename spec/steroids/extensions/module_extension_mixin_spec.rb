# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ModuleExtension, "mixin helpers" do
  describe "#mixin_alias" do
    it "defines instance and singleton aliases that delegate to a class method" do
      klass = Class.new do
        def self.greet(name) = "hello, #{name}"
        send(:mixin_alias, :hello, :greet)
      end

      expect(klass.hello("Ada")).to eq("hello, Ada")
      expect(klass.new.hello("Bo")).to eq("hello, Bo")
    end
  end

  describe "#mixin" do
    it "exposes a class method on the instance" do
      klass = Class.new do
        def self.tag = "from-class"
        send(:mixin, :tag)
      end
      expect(klass.new.tag).to eq("from-class")
    end

    it "raises ArgumentError when the target is not a class method" do
      klass = Class.new
      expect { klass.send(:mixin, :no_such_method) }.to raise_error(ArgumentError, /class method/)
    end
  end
end
