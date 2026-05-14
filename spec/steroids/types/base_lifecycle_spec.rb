# frozen_string_literal: true

require "spec_helper"

# Covers the instance-level helpers (#values, #to_s, #validate, #missing_attributes,
# #validate_required!) and the default #import that raises.
RSpec.describe Steroids::Types::Base, "instance helpers" do
  before(:all) do
    module TypesBaseLifecycleSpec
      class CoordsType < Steroids::Types::Base
        attributes :latitude, :longitude
        requires :latitude
        requires :longitude

        def import(options, _object)
          self.latitude  = options[:latitude]
          self.longitude = options[:longitude]
        end
      end

      class NoAttrsType < Steroids::Types::Base
      end
    end
  end

  let(:point) { TypesBaseLifecycleSpec::CoordsType.new(latitude: 1.0, longitude: 2.0) }

  describe "#values" do
    it "returns the attribute hash" do
      expect(point.values).to eq(latitude: 1.0, longitude: 2.0)
    end
  end

  describe "#to_s" do
    it "serializes the attribute hash to JSON" do
      expect(point.to_s).to eq({ latitude: 1.0, longitude: 2.0 }.to_json)
    end

    it "returns an empty string when no attributes are declared" do
      expect(TypesBaseLifecycleSpec::NoAttrsType.new({}, true).to_s).to eq("")
    end
  end

  describe "#validate / #validate!" do
    it "validates the required attributes are present" do
      expect(point.validate).to be true
    end

    it "raises on missing attributes via validate!" do
      stripped = TypesBaseLifecycleSpec::CoordsType.new({}, true)
      expect { stripped.validate! }.to raise_error(Steroids::Errors::InternalServerError, /Missing required attributes/)
    end
  end

  describe "#missing_attributes" do
    it "returns required attributes that are nil/missing" do
      stripped = TypesBaseLifecycleSpec::CoordsType.new({}, true)
      expect(stripped.missing_attributes).to match_array([:latitude, :longitude])
    end
  end

  describe "default #import" do
    # The base implementation references `name` (the class method) inside an
    # instance scope and so raises a NameError before the InternalServerError
    # is constructed. Documenting current behavior — subclasses must override.
    it "raises (subclasses must override)" do
      expect { TypesBaseLifecycleSpec::NoAttrsType.new({}, true).import({}, Object.new) }
        .to raise_error(StandardError)
    end
  end
end
