# frozen_string_literal: true

require "spec_helper"

RSpec.describe Steroids::Support::ServicableMethods do
  before(:all) do
    module ServicableMethodsSpec
      class UserService < Steroids::Services::Base
        success_notice "User operation completed"

        def initialize(name:, email: nil)
          @name = name
          @email = email
        end

        def process
          if @name.blank?
            errors.add("Name is required")
            return
          end

          { name: @name, email: @email }
        end
      end

      class Controller
        include Steroids::Support::ServicableMethods

        service :create_user, class_name: "ServicableMethodsSpec::UserService"
        service :update_user, class_name: "ServicableMethodsSpec::UserService"

        attr_accessor :redirected_to, :rendered, :flash

        def initialize
          @flash = {}
        end

        def redirect_to(path, options = {})
          @redirected_to = path
          @flash[:notice] = options[:notice] if options[:notice]
          @flash[:alert]  = options[:alert]  if options[:alert]
        end

        def render(template, options = {})
          @rendered = template
          @flash[:alert] = options[:alert] if options[:alert]
        end
      end
    end
  end

  let(:controller) { ServicableMethodsSpec::Controller.new }

  describe "service macro" do
    it "creates an instance method on the host class" do
      expect(controller).to respond_to(:create_user)
    end

    it "returns the process result when called without a block" do
      result = controller.create_user(name: "John", email: "john@example.com")
      expect(result).to eq(name: "John", email: "john@example.com")
    end

    it "yields the service via noticable to the block on success" do
      service_instance = nil
      block_called = false

      controller.create_user(name: "John") do |_service, _outcome, **options|
        block_called = true
        service_instance = options[:noticable]

        if service_instance&.success?
          controller.redirect_to "/users", notice: service_instance.notice
        end
      end

      expect(block_called).to be true
      expect(service_instance).to be_success
      expect(controller.redirected_to).to eq("/users")
      expect(controller.flash[:notice]).to eq("User operation completed")
    end

    it "yields with errors on the noticable on failure" do
      controller.create_user(name: "") do |_service, _outcome, **options|
        noticable = options[:noticable]
        controller.render(:new, alert: noticable.errors.full_messages) if noticable&.errors?
      end

      expect(controller.rendered).to eq(:new)
      expect(controller.flash[:alert]).to eq("Name is required")
    end

    it "supports multiple services on the same controller" do
      multi_class = Class.new do
        include Steroids::Support::ServicableMethods
        service :first_service,  class_name: "ServicableMethodsSpec::UserService"
        service :second_service, class_name: "ServicableMethodsSpec::UserService"
        service :third_service,  class_name: "ServicableMethodsSpec::UserService"
      end
      instance = multi_class.new
      expect(instance).to respond_to(:first_service, :second_service, :third_service)
    end
  end
end
