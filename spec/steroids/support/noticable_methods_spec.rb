# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Support::NoticableMethods do
  let(:host_class) do
    Class.new do
      include Steroids::Support::NoticableMethods
    end
  end
  let(:noticable) { host_class.new }

  describe "errors collection" do
    it "starts empty" do
      expect(noticable.errors).not_to be_any
      expect(noticable.errors?).to be false
    end

    it "accepts a string message" do
      noticable.errors.add("Error message")
      expect(noticable.errors).to be_any
      expect(noticable.errors?).to be true
      expect(noticable.errors.full_messages).to include("Error message")
    end

    it "accepts a message with an exception" do
      exception = StandardError.new("Original error")
      noticable.errors.add("Wrapped error", exception)
      expect(noticable.errors.full_messages).to eq("Wrapped error")
    end

    it "raises TypeError when the first arg is a symbol (not the AR errors API)" do
      expect { noticable.errors.add(:base, "Message") }.to raise_error(TypeError)
    end

    it "joins multiple errors with newlines" do
      noticable.errors.add("First error")
      noticable.errors.add("Second error")
      noticable.errors.add("Third error")
      expect(noticable.errors.full_messages).to eq("First error\nSecond error\nThird error")
    end

    it "supports the << operator" do
      noticable.errors << "Error via operator"
      expect(noticable.errors?).to be true
      expect(noticable.errors.full_messages).to include("Error via operator")
    end
  end

  describe "notices collection" do
    it "joins multiple notices with newlines" do
      noticable.notices.add("First notice")
      noticable.notices.add("Second notice")
      expect(noticable.notices).to be_any
      expect(noticable.notices.full_messages).to eq("First notice\nSecond notice")
    end
  end

  describe "#success?" do
    it "is true when no errors" do
      expect(noticable.success?).to be true

      noticable.notices.add("Just a notice")
      expect(noticable.success?).to be true

      noticable.errors.add("An error")
      expect(noticable.success?).to be false
    end
  end

  describe "#errors?" do
    it "is true when errors exist" do
      expect(noticable.errors?).to be false
      noticable.errors.add("An error")
      expect(noticable.errors?).to be true
    end
  end

  describe "#flash_key" do
    it "returns :notice on success and :alert on errors" do
      expect(noticable.flash_key).to eq(:notice)
      noticable.notices.add("Just a notice")
      expect(noticable.flash_key).to eq(:notice)
      noticable.errors.add("An error")
      expect(noticable.flash_key).to eq(:alert)
    end
  end

  describe "#notice" do
    it "returns the joined error messages when errors exist" do
      noticable.errors.add("Error 1")
      noticable.errors.add("Error 2")
      expect(noticable.notice).to eq("Error 1\nError 2")
    end

    it "returns the joined notices when no errors and notices present" do
      noticable.notices.add("Notice 1")
      noticable.notices.add("Notice 2")
      expect(noticable.notice).to eq("Notice 1\nNotice 2")
    end

    it "falls back to the class-declared success_notice" do
      with_success_notice = Class.new do
        include Steroids::Support::NoticableMethods
        success_notice "Custom success message"
      end
      expect(with_success_notice.new.notice).to eq("Custom success message")
    end

    it "humanizes the class name when no success_notice is declared" do
      stub_const("MySpecialOperation", Class.new do
        include Steroids::Support::NoticableMethods
      end)
      expect(MySpecialOperation.new.notice).to eq("My special operation succeeded")
    end
  end

  describe "#merge" do
    it "combines errors and notices from another noticable" do
      other = host_class.new
      other.errors.add("Other error 1")
      other.errors.add("Other error 2")
      other.notices.add("Other notice")

      noticable.errors.add("My error")
      noticable.noticable.merge(other.noticable)

      errors_array = noticable.errors.map { |e| e[:message] }
      expect(errors_array).to include("My error")
      expect(noticable.errors.to_a.size).to eq(3)
    end
  end
end
