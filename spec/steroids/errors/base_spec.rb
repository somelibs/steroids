# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Errors::Base do
  class CustomTestError < described_class
    self.default_message = "Custom default message"
    self.default_status = :unprocessable_content
  end

  class UnregisteredCustomError < described_class
    self.default_message = "Unregistered default message"
    self.default_status = :forbidden
  end

  describe "#initialize" do
    it "accepts a positional string message" do
      error = described_class.new("Something went wrong")

      expect(error.message).to eq("Something went wrong")
      expect(error.status).to eq(:internal_server_error)
    end

    it "uses the class default_message when no message is provided" do
      expect(described_class.new.message).to eq("Oops, something went wrong (Unknown error)")
    end

    it "uses subclass defaults" do
      error = CustomTestError.new
      expect(error.message).to eq("Custom default message")
      expect(error.status).to eq(:unprocessable_content)
    end

    it "accepts kwarg options" do
      original = StandardError.new("Original")
      error = described_class.new(
        message: "Custom message",
        status: :bad_request,
        cause: original,
        context: { user_id: 123, action: "update" }
      )

      expect(error.message).to eq("Custom message")
      expect(error.status).to eq(:bad_request)
      expect(error.code).to eq(520)
      expect(error.cause).to eq(original)
      expect(error.context).to eq(user_id: 123, action: "update")
    end
  end

  describe "default HTTP error classes" do
    {
      Steroids::Errors::BadRequestError => [:bad_request, "Request failed (BadRequestError)."],
      Steroids::Errors::UnauthorizedError => [:unauthorized, "You shall not pass! (Unauthorized)"],
      Steroids::Errors::ForbiddenError => [:forbidden, "You shall not pass! (ForbiddenError)"],
      Steroids::Errors::NotFoundError => [:not_found, "We couldn't find what you were looking for (NotfoundError)"],
      Steroids::Errors::ConflictError => [:conflict, "Already exists (InternalConflictError)"],
      Steroids::Errors::UnprocessableEntityError => [:unprocessable_content,
                                                     "We couldn't understand your request (UnprocessableEntityError)"],
      Steroids::Errors::InternalServerError => [:internal_server_error,
                                                "Oops, something went wrong (InternalServerError)"],
      Steroids::Errors::NotImplementedError => [:not_implemented,
                                                "This feature hasn't been implemented yet (NotImplementedError)"]
    }.each do |klass, (status, message)|
      it "#{klass.name.split('::').last} has its registered status and default message" do
        error = klass.new
        expect(error.status).to eq(status)
        expect(error.message).to eq(message)
      end
    end
  end

  describe "JSON serialization" do
    it "produces parseable JSON" do
      error = Steroids::Errors::BadRequestError.new(
        "Invalid input",
        code: "INVALID_INPUT",
        context: { field: "email" }
      )

      expect(error).to respond_to(:to_json)
      expect { JSON.parse(error.to_json) }.not_to raise_error
    end
  end

  describe "logging" do
    it "is not logged by default" do
      expect(described_class.new("Test error").logged).to be_nil
    end

    it "marks as logged after a manual log!" do
      error = described_class.new("Test error")
      error.log!
      expect(error.logged).to be true
    end

    it "auto-logs when log option is true" do
      allow(Steroids::Logger).to receive(:print).and_return(true)
      error = described_class.new("Test error", log: true)
      expect(error.logged).to be true
    end
  end

  describe "cause handling" do
    it "preserves the cause exception and exposes cause_message" do
      original = StandardError.new("Original error")

      begin
        raise original
      rescue => e
        error = described_class.new("Wrapped error", cause: e)
        expect(error.cause).to eq(original)
        expect(error.cause_message).to eq("Original error")
      end
    end

    it "uses the cause backtrace when present" do
      raise StandardError.new("Original")
    rescue => e
      error = described_class.new("Wrapped", cause: e)
      expect(error.backtrace).to eq(e.backtrace)
    end
  end

  describe "backtrace" do
    it "captures a backtrace" do
      error = described_class.new("Test error")
      expect(error.backtrace).to be_a(Array)
    end
  end

  describe "context" do
    it "exposes the context hash" do
      error = described_class.new(
        "Error with context",
        context: { user_id: 42, request_id: "abc-123" }
      )
      expect(error.context).to include(user_id: 42, request_id: "abc-123")
    end
  end

  describe "status resolution" do
    it "falls back to default_status for unregistered subclasses" do
      expect(ActionDispatch::ExceptionWrapper.rescue_responses).not_to have_key(UnregisteredCustomError.name)

      error = UnregisteredCustomError.new
      expect(error.status).to eq(:forbidden)
      expect(error.message).to eq("Unregistered default message")
    end

    it "uses the registered status for registered classes" do
      expect(Steroids::Errors::UnauthorizedError.new.status).to eq(:unauthorized)
    end

    it "lets an explicit status: kwarg override registration and default_status" do
      expect(Steroids::Errors::UnauthorizedError.new(status: :conflict).status).to eq(:conflict)
    end
  end

  describe "raise/rescue" do
    it "can be raised as itself" do
      expect { raise Steroids::Errors::BadRequestError.new("Bad request") }
        .to raise_error(Steroids::Errors::BadRequestError, "Bad request")
    end

    it "is also a StandardError" do
      raise Steroids::Errors::NotFoundError.new("Not found")
    rescue => e
      expect(e).to be_a(Steroids::Errors::NotFoundError)
      expect(e.message).to eq("Not found")
    end
  end
end
