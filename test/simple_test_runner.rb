#!/usr/bin/env ruby

# Simple test runner for Steroids gem
# This bypasses Rails test environment issues

require 'bundler/setup'
require 'minitest/autorun'
require 'active_support'
require 'active_model'
require 'active_record'
require 'rainbow'

# Load Steroids
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "steroids"

# Mock Rails for testing
module Rails
  def self.env
    ActiveSupport::StringInquirer.new("test")
  end
  
  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
  
  def self.root
    Pathname.new(File.expand_path("..", __dir__))
  end
end

# Simple test to verify Steroids loads
class SteroidsBasicTest < Minitest::Test
  def test_steroids_module_exists
    assert_equal Module, Steroids.class
  end
  
  def test_version_defined
    assert Steroids::VERSION
    puts "Steroids version: #{Steroids::VERSION}"
  end
  
  def test_core_modules_loaded
    assert Steroids::Services
    assert Steroids::Services::Base
    assert Steroids::Errors
    assert Steroids::Errors::Base
    assert Steroids::Support::NoticableMethods
    assert Steroids::Support::ServicableMethods
  end
  
  def test_error_classes_defined
    assert Steroids::Errors::BadRequestError
    assert Steroids::Errors::UnauthorizedError
    assert Steroids::Errors::ForbiddenError
    assert Steroids::Errors::NotFoundError
  end
end

# Test NoticableMethods
class NoticableTest < Minitest::Test
  class TestClass
    include Steroids::Support::NoticableMethods
  end
  
  def setup
    @obj = TestClass.new
  end
  
  def test_errors_add_with_string_only
    @obj.errors.add("Test error")
    assert @obj.errors?
    assert_equal "Test error", @obj.errors.full_messages
  end
  
  def test_errors_add_rejects_symbol
    assert_raises(TypeError) do
      @obj.errors.add(:base, "Message")
    end
  end
  
  def test_success_when_no_errors
    assert @obj.success?
    @obj.errors.add("Error")
    assert !@obj.success?
  end
end

# Test basic service
class ServiceTest < Minitest::Test
  class SimpleService < Steroids::Services::Base
    success_notice "Done!"
    
    def initialize(value:)
      @value = value
    end
    
    def process
      @value * 2
    end
  end
  
  class ErrorService < Steroids::Services::Base
    def process
      errors.add("Something went wrong")
    end
  end
  
  def test_successful_service
    service = SimpleService.new(value: 5)
    result = service.call
    
    assert_equal 10, result
    assert service.success?
    assert_equal "Done!", service.notice
  end
  
  def test_service_with_errors
    service = ErrorService.new
    service.call
    
    assert service.errors?
    assert !service.success?
    assert_includes service.errors.full_messages, "Something went wrong"
  end
  
  def test_class_call_method
    service = SimpleService.call(value: 3)
    assert service.success?
  end
end

# Test error classes
class ErrorTest < Minitest::Test
  def test_basic_error_creation
    error = Steroids::Errors::Base.new("Test error")
    assert_equal "Test error", error.message
  end
  
  def test_http_errors_have_correct_status
    assert_equal :bad_request, Steroids::Errors::BadRequestError.new.status
    assert_equal :unauthorized, Steroids::Errors::UnauthorizedError.new.status
    assert_equal :forbidden, Steroids::Errors::ForbiddenError.new.status
    assert_equal :not_found, Steroids::Errors::NotFoundError.new.status
  end
  
  def test_error_with_context
    error = Steroids::Errors::Base.new(
      "Error",
      context: { user_id: 123 }
    )
    assert_equal({ user_id: 123 }, error.context)
  end
end

# Run summary
puts "\n" + "="*60
puts "Steroids Gem Test Suite - Simple Runner"
puts "="*60
puts "Running tests for core Steroids functionality..."
puts "="*60