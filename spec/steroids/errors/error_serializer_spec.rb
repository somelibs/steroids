# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::ErrorSerializer do
  def serialize(error)
    described_class.new(error).serializable_hash
  end

  # Stubs Rails.env without producing "method redefined" warnings.
  def with_rails_env(env)
    original = Rails.env
    silence_warnings do
      Rails.define_singleton_method(:env) { ActiveSupport::EnvironmentInquirer.new(env) }
    end
    yield
  ensure
    silence_warnings do
      Rails.define_singleton_method(:env) { original }
    end
  end

  describe "production env" do
    it "includes the message attribute" do
      error = Steroids::Errors::UnauthorizedError.new(message: "Unauthorized.")

      with_rails_env("production") do
        hash = serialize(error)
        expect(hash.keys).to include(:message)
        expect(hash[:message]).to eq("Unauthorized.")
      end
    end

    it "omits the exception attribute (dev-only)" do
      error = Steroids::Errors::UnauthorizedError.new(message: "Unauthorized.")

      with_rails_env("production") do
        expect(serialize(error).keys).not_to include(:exception)
      end
    end
  end

  describe "development env" do
    it "includes both message and exception" do
      error = Steroids::Errors::BadRequestError.new(
        message: "Invalid input",
        cause: StandardError.new("upstream failure")
      )

      with_rails_env("development") do
        hash = serialize(error)
        expect(hash.keys).to include(:message, :exception)
        expect(hash[:exception]).to eq("StandardError")
        expect(hash[:message]).to match(/Invalid input/)
      end
    end
  end

  describe "core envelope" do
    it "always exposes id, code, status, errors, timestamp" do
      error = Steroids::Errors::NotFoundError.new(message: "Not here")
      with_rails_env("production") do
        hash = serialize(error)
        [:id, :code, :status, :errors, :timestamp].each do |key|
          expect(hash.keys).to include(key)
        end
      end
    end
  end
end
