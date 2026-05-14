# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Controllers::SerializersHelper do
  let(:host_class) do
    Class.new do
      include Steroids::Controllers::SerializersHelper
    end
  end

  describe ".default_serializer" do
    it "stores the serializer class on the host class" do
      host_class.default_serializer("MySerializer")
      expect(host_class.serializer).to eq("MySerializer")
    end

    it "is per-class (not shared)" do
      other = Class.new { include Steroids::Controllers::SerializersHelper }
      host_class.default_serializer("HostSerializer")
      other.default_serializer("OtherSerializer")

      expect(host_class.serializer).to eq("HostSerializer")
      expect(other.serializer).to eq("OtherSerializer")
    end
  end
end
