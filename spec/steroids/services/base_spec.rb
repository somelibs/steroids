# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Services::Base do
  before(:all) do
    module BaseServiceSpec
      class SuccessfulService < Steroids::Services::Base
        success_notice "Operation completed successfully"

        def initialize(value:)
          @value = value
        end

        def process
          @value * 2
        end
      end

      class FailingService < Steroids::Services::Base
        success_notice "This should not appear"

        def process
          errors.add("Something went wrong")
          errors.add("Another error occurred")
        end
      end

      class ExceptionService < Steroids::Services::Base
        def process
          raise StandardError, "Unexpected error"
        end
      end

      class ValidatedService < Steroids::Services::Base
        success_notice "Validated successfully"

        def initialize(email:)
          @email = email
        end

        private

        def process
          validate_email!
          "Email is valid: #{@email}"
        end

        def validate_email!
          if @email.blank?
            errors.add("Email cannot be blank")
            drop!
          end

          unless @email.include?("@")
            errors.add("Email format is invalid")
            drop!
          end
        end
      end

      class CallbackService < Steroids::Services::Base
        before_process :setup
        after_process :cleanup

        attr_reader :setup_called, :cleanup_called

        def initialize
          @setup_called = false
          @cleanup_called = false
        end

        def process
          "processed"
        end

        private

        def setup
          @setup_called = true
        end

        def cleanup(_result)
          @cleanup_called = true
        end
      end

      class DroppingService < Steroids::Services::Base
        attr_reader :after_drop_called

        def initialize
          @after_drop_called = false
        end

        def process
          drop!("Critical error")
          @after_drop_called = true
        end
      end

      class TransactionWrappedService < Steroids::Services::Base
        def process
          "wrapped"
        end
      end

      class TransactionOptedOutService < Steroids::Services::Base
        wrap_in_transaction false
        def process
          "not wrapped"
        end
      end
    end
  end

  describe "basic functionality" do
    it "returns the process result on success" do
      service = BaseServiceSpec::SuccessfulService.new(value: 5)
      expect(service.call).to eq(10)
      expect(service).to be_success
      expect(service.errors?).to be false
      expect(service.notice).to eq("Operation completed successfully")
    end

    it "raises noticable runtime exception when errors accumulate and no block is given" do
      service = BaseServiceSpec::FailingService.new
      expect { service.call }
        .to raise_error(Steroids::Support::NoticableMethods::RuntimeException, /Something went wrong/)
      expect(service.errors?).to be true
      # The auto-drop! flow inside exec_process re-enters errors with the
      # default "Runtime error" string of the RuntimeError sentinel — three lines total.
      expect(service.errors.full_messages.split("\n")).to include(
        "Something went wrong",
        "Another error occurred"
      )
    end

    it "swallows the noticable exception when a block is given" do
      service = BaseServiceSpec::FailingService.new
      received_noticable = nil
      service.call do |_service, _outcome, **options|
        received_noticable = options[:noticable]
      end
      expect(received_noticable).to be_errors
      expect(received_noticable.errors.full_messages).to include("Something went wrong")
    end

    it "via the class method returns the process result and yields the block on success" do
      result = BaseServiceSpec::SuccessfulService.call(value: 3)
      expect(result).to eq(6)

      BaseServiceSpec::SuccessfulService.call(value: 3) do |_service, _outcome, **options|
        expect(options[:noticable]).to be_success
      end
    end
  end

  describe "validation" do
    it "drops execution when a validation error is added" do
      service = BaseServiceSpec::ValidatedService.new(email: "")
      expect { service.call }.to raise_error(Steroids::Errors::Base)
      expect(service.errors?).to be true
      expect(service.errors.full_messages).to include("Email cannot be blank")
    end

    it "processes successfully when validation passes" do
      service = BaseServiceSpec::ValidatedService.new(email: "test@example.com")
      result = service.call
      expect(service).to be_success
      expect(result).to eq("Email is valid: test@example.com")
    end
  end

  describe "callbacks" do
    it "fires before_process and after_process callbacks" do
      service = BaseServiceSpec::CallbackService.new
      service.call
      expect(service.setup_called).to be true
      expect(service.cleanup_called).to be true
    end
  end

  describe "exception handling" do
    it "captures the exception into errors and exposes it through the block" do
      service = BaseServiceSpec::ExceptionService.new
      received = nil
      service.call do |_service, _outcome, **options|
        received = options[:noticable]
      end

      expect(received).to be_errors
      expect(service.errors?).to be true
    end
  end

  describe "drop!" do
    it "halts execution and registers the message" do
      service = BaseServiceSpec::DroppingService.new
      expect { service.call }.to raise_error(Steroids::Errors::Base, /Critical error/)
      expect(service.after_drop_called).to be false
      expect(service.errors?).to be true
    end
  end

  describe "transaction wrapping" do
    it "wraps by default, with no shared class variable that could leak" do
      expect(described_class.class_variable_defined?(:@@wrap_in_transaction)).to be false
      expect(BaseServiceSpec::TransactionWrappedService.new.send(:wrap_in_transaction?)).to be true
    end

    it "can be opted out of per-class via the macro" do
      expect(BaseServiceSpec::TransactionOptedOutService.new.send(:wrap_in_transaction?)).to be false
    end

    it "does not leak a per-class opt-out to sibling services" do
      expect(BaseServiceSpec::TransactionWrappedService.new.send(:wrap_in_transaction?)).to be true
      expect(BaseServiceSpec::TransactionOptedOutService.new.send(:wrap_in_transaction?)).to be false
    end

    # Regression: the wrap flag used to be a shared `@@wrap_in_transaction` class
    # variable. A subclass assigning it wrote the ANCESTOR's variable, so a
    # single `@@wrap_in_transaction = false` silently disabled the transaction
    # wrap for EVERY service in the host app. The flag is now a per-class
    # class_attribute; a stray class-variable assignment must be inert.
    it "ignores a stray @@wrap_in_transaction class-variable assignment (the old footgun)" do
      stray = Class.new(Steroids::Services::Base) do
        class_variable_set(:@@wrap_in_transaction, false) # simulate the old mistake
        def process; end
      end

      expect(stray.new.send(:wrap_in_transaction?)).to be true
      expect(BaseServiceSpec::TransactionWrappedService.new.send(:wrap_in_transaction?)).to be true
      expect(described_class.class_variable_defined?(:@@wrap_in_transaction)).to be false
    end
  end
end
