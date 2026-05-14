# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ModuleExtension do
  describe "#create_namespace" do
    it "builds a single-level module" do
      ns = Module.new
      inner = ns.create_namespace("Inner")
      expect(inner).to be_a(Module)
      expect(inner.name.split("::").last).to eq("Inner")
    end

    it "builds nested modules" do
      ns = Module.new
      deep = ns.create_namespace("A::B::C")
      expect(deep).to be_a(Module)
      expect(ns.const_defined?(:A)).to be true
      expect(ns.const_get(:A).const_defined?(:B)).to be true
      expect(ns.const_get(:A).const_get(:B).const_defined?(:C)).to be true
    end

    it "is idempotent — returns the existing module on repeat" do
      ns = Module.new
      first  = ns.create_namespace("X::Y")
      second = ns.create_namespace("X::Y")
      expect(first).to equal(second)
    end

    it "strips a leading ::" do
      ns = Module.new
      expect(ns.create_namespace("::Z")).to be_a(Module)
    end
  end

  describe "#grundclass" do
    it "returns self for non-singleton modules" do
      mod = Module.new
      expect(mod.grundclass).to equal(mod)
    end
  end
end
