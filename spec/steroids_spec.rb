# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids do
  it "is a module" do
    expect(described_class).to be_a(Module)
  end

  it "exposes a version constant" do
    expect(Steroids::VERSION).to be_a(String)
  end

  describe "core modules" do
    it "loads service infrastructure" do
      expect(Steroids::Services).to be_a(Module)
      expect(Steroids::Services::Base).to be < Steroids::Support::MagicClass
    end

    it "loads support modules" do
      expect(Steroids::Support::NoticableMethods).to be_a(Module)
      expect(Steroids::Support::ServicableMethods).to be_a(Module)
    end

    it "loads the logger" do
      expect(Steroids::Logger).to be_a(Class)
    end
  end

  describe "error classes" do
    [
      :BadRequestError, :UnauthorizedError, :ForbiddenError, :NotFoundError, :ConflictError, :UnprocessableEntityError, :InternalServerError, :NotImplementedError
    ].each do |error_name|
      it "defines #{error_name}" do
        klass = Steroids::Errors.const_get(error_name)
        expect(klass).to be < Steroids::Errors::Base
      end
    end
  end
end
