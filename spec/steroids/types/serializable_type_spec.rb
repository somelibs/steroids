# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Types::SerializableType do
  let(:simple_type) do
    Class.new(described_class) do
      attribute :name
      attribute :email
    end
  end

  it "defines readers and writers for declared attributes" do
    instance = simple_type.new
    instance.name = "Ada"
    instance.email = "ada@example.com"

    expect(instance.name).to eq("Ada")
    expect(instance.email).to eq("ada@example.com")
  end

  it "tracks declared attributes on the class" do
    expect(simple_type.attributes).to eq([:name, :email])
  end

  it "supports mass assignment via ActiveModel::Model initializer" do
    instance = simple_type.new(name: "Bob", email: "bob@example.com")
    expect(instance.name).to eq("Bob")
    expect(instance.email).to eq("bob@example.com")
  end

  it "aliases attr_accessor to attribute (so it tracks too)" do
    klass = Class.new(described_class) do
      attr_accessor :foo, :bar
    end

    expect(klass.attributes).to eq([:foo, :bar])
    instance = klass.new(foo: 1, bar: 2)
    expect(instance.foo).to eq(1)
    expect(instance.bar).to eq(2)
  end
end
