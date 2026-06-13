# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Services::Base, "lifecycle hooks & controller patterns" do
  before(:all) do
    module LifecycleSpec
      class CreateUserService < Steroids::Services::Base
        success_notice "User created successfully"

        def initialize(name:, email:)
          @name = name
          @email = email
        end

        def process
          if @email.blank?
            errors.add("Email cannot be blank")
            return nil
          end

          { id: 123, name: @name, email: @email }
        end
      end

      class LifecycleService < Steroids::Services::Base
        success_notice "Process completed"

        before_process :setup_resources
        after_process :cleanup_resources

        attr_reader :setup_called, :cleanup_called, :ensure_called, :rescue_called

        def initialize(should_fail: false, should_drop: false)
          @should_fail = should_fail
          @should_drop = should_drop
          @setup_called = false
          @cleanup_called = false
          @ensure_called = false
          @rescue_called = false
        end

        def process
          drop!("Dropped intentionally") if @should_drop
          raise StandardError, "Failed intentionally" if @should_fail

          "success"
        end

        def rescue!(exception)
          @rescue_called = true
          errors.add("Rescued: #{exception.message}")
        end

        def ensure!
          @ensure_called = true
        end

        private

        def setup_resources
          @setup_called = true
        end

        def cleanup_resources(_result)
          @cleanup_called = true
        end
      end

      class ChainableService < Steroids::Services::Base
        success_notice "Chain completed"

        def initialize(step:, previous_result: nil)
          @step = step
          @previous_result = previous_result
        end

        def process
          return nil if @previous_result.nil? && @step > 1

          case @step
          when 1 then { step_1: "completed" }
          when 2 then @previous_result.merge(step_2: "completed")
          when 3 then @previous_result.merge(step_3: "completed", final: true)
          end
        end
      end

      class MockController
        include Steroids::Support::ServicableMethods

        service :create_user, class_name: "LifecycleSpec::CreateUserService"

        attr_reader :redirected_to, :notice, :alert

        def handle_create(name:, email:)
          create_user(name: name, email: email) do |_service, _outcome, **options|
            noticable = options[:noticable]
            if noticable&.success?
              @redirected_to = "/users"
              @notice = noticable.notice
            elsif noticable
              @alert = noticable.errors.full_messages
            end
          end
        end
      end
    end
  end

  # Disable transaction wrapping for tests that don't touch the DB. Uses the
  # per-class `wrap_in_transaction_override` class_attribute (reset to nil after)
  # — the shared `@@wrap_in_transaction` class variable was removed because a
  # subclass assigning it leaked the setting across the whole hierarchy.
  around do |example|
    described_class.wrap_in_transaction_override = false
    example.run
  ensure
    described_class.wrap_in_transaction_override = nil
  end

  describe "basic class-method usage" do
    it "returns the process payload directly on success" do
      result = LifecycleSpec::CreateUserService.call(name: "John", email: "john@example.com")
      expect(result).to eq(id: 123, name: "John", email: "john@example.com")
    end

    it "raises the noticable runtime exception when called without a block on failure" do
      expect { LifecycleSpec::CreateUserService.call(name: "John", email: "") }
        .to raise_error(Steroids::Support::NoticableMethods::RuntimeException, /Email cannot be blank/)
    end

    it "exposes noticable status on the service instance after a successful run" do
      service = LifecycleSpec::CreateUserService.new(name: "John", email: "john@example.com")
      result = service.call

      expect(service).to be_success
      expect(service.errors?).to be false
      expect(service.notice).to eq("User created successfully")
      expect(result).to eq(id: 123, name: "John", email: "john@example.com")
    end
  end

  describe "block pattern" do
    it "yields the success branch when noticable.success?" do
      redirected = false

      LifecycleSpec::CreateUserService.call(name: "Jane", email: "jane@example.com") do |_service, _outcome, **options|
        noticable = options[:noticable]
        if noticable&.success?
          redirected = true
          expect(noticable.notice).to eq("User created successfully")
        end
      end

      expect(redirected).to be true
    end

    it "yields the errors branch when validation fails" do
      alert_message = nil

      LifecycleSpec::CreateUserService.call(name: "Jane", email: "") do |_service, _outcome, **options|
        noticable = options[:noticable]
        alert_message = noticable.errors.full_messages if noticable&.errors?
      end

      expect(alert_message).to eq("Email cannot be blank")
    end
  end

  describe "lifecycle methods" do
    it "executes setup, cleanup, ensure! in the success path" do
      service = LifecycleSpec::LifecycleService.new
      result = service.call

      expect(service.setup_called).to be true
      expect(service.cleanup_called).to be true
      expect(service.ensure_called).to be true
      expect(service.rescue_called).to be false
      expect(result).to eq("success")
    end

    it "drop! halts execution, sets errors, skips after_process, runs ensure!" do
      service = LifecycleSpec::LifecycleService.new(should_drop: true)
      expect { service.call }.to raise_error(Steroids::Errors::Base, /Dropped intentionally/)

      expect(service.setup_called).to be true
      expect(service.cleanup_called).to be false
      expect(service.ensure_called).to be true
      expect(service.errors?).to be true
      expect(service.errors.full_messages).to include("Dropped intentionally")
    end

    it "rescue! handles exceptions (via block to swallow the raise)" do
      service = LifecycleSpec::LifecycleService.new(should_fail: true)

      service.call do |_service, _outcome, **options|
        noticable = options[:noticable]
        expect(noticable).to be_errors
        expect(noticable.errors.full_messages).to include("Rescued: Failed intentionally")
      end

      expect(service.rescue_called).to be true
      expect(service.ensure_called).to be true
    end

    it "ensure! always runs (success, drop, exception)" do
      success = LifecycleSpec::LifecycleService.new
      success.call
      expect(success.ensure_called).to be true

      dropped = LifecycleSpec::LifecycleService.new(should_drop: true)
      expect { dropped.call }.to raise_error(Steroids::Errors::Base)
      expect(dropped.ensure_called).to be true

      raised = LifecycleSpec::LifecycleService.new(should_fail: true)
      raised.call { |_, _, **opts| } # block prevents propagation
      expect(raised.ensure_called).to be true
    end
  end

  describe "controller integration via service macro" do
    let(:controller) { LifecycleSpec::MockController.new }

    it "routes the success branch correctly" do
      user = controller.handle_create(name: "Alice", email: "alice@example.com")
      expect(controller.redirected_to).to eq("/users")
      expect(controller.notice).to eq("User created successfully")
      expect(user).to eq(id: 123, name: "Alice", email: "alice@example.com")
    end

    it "routes the error branch correctly" do
      result = controller.handle_create(name: "Bob", email: "")
      expect(controller.redirected_to).to be_nil
      expect(controller.alert).to eq("Email cannot be blank")
      expect(result).to be_nil
    end
  end

  describe "service chaining" do
    it "passes results between successive .call invocations" do
      r1 = LifecycleSpec::ChainableService.call(step: 1)
      r2 = LifecycleSpec::ChainableService.call(step: 2, previous_result: r1)
      r3 = LifecycleSpec::ChainableService.call(step: 3, previous_result: r2)

      expect(r3).to eq(
        step_1: "completed",
        step_2: "completed",
        step_3: "completed",
        final: true
      )
    end
  end
end
