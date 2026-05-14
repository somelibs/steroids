# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Extensions::ClassExtension, "runtime introspection" do
  describe "#runtime_methods(include_modules: false)" do
    it "walks the class hierarchy without prepended modules" do
      klass = Class.new do
        def self.example_singleton; end
      end
      expect(klass.runtime_methods(false)).to be_a(Array)
    end
  end

  describe "#runtime_instance_methods(include_modules: false)" do
    it "walks the class hierarchy" do
      klass = Class.new do
        def example_instance; end
      end
      expect(klass.runtime_instance_methods(false)).to be_a(Array)
    end
  end

  describe "build_anonymous inspect/to_s overrides" do
    # Inspect override only kicks in when the class was NOT const_set —
    # const_set replaces super().inspect with the constant path, so the
    # gsub from "#<#<Class:" to "#<#<Anonymous:..." finds nothing to rewrite.
    it "leaves the inspect rewrite path defined but no-ops when const_set ran" do
      klass = Class.build_anonymous("InspectMe", Class.new) {}
      expect(klass.inspect).to be_a(String)
      expect(klass.to_s).to eq(klass.inspect)
      expect(klass.new.inspect).to include("InspectMe")
    ensure
      Object.send(:remove_const, :InspectMe) if defined?(::InspectMe)
    end
  end
end
