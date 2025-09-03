$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Set Rails environment before loading Rails
ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "minitest/pride"

# Load Rails components needed for testing
require "rails"
require "active_support"
require "active_support/test_case"
require "active_support/core_ext"
require "active_model"
require "active_job"
require "active_record"

# Create a minimal Rails application for testing
module TestApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.logger = Logger.new(nil)  # Silence logs during tests
  end
end

# Initialize the Rails app
Rails.application.initialize!

# Setup ActiveRecord with in-memory SQLite database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Create a simple schema for testing
ActiveRecord::Schema.define do
  create_table :test_records, force: true do |t|
    t.string :name
    t.timestamps
  end
end

# Mock Sidekiq if not available
unless defined?(Sidekiq)
  module Sidekiq
    class ProcessSet
      def initialize; end
      def any?; false; end
    end
  end
end

# Load Steroids after Rails is initialized
require "steroids"

# Register custom error classes with Rails' exception wrapper
# This is needed for the error classes to return their correct status codes
ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  "Steroids::Errors::BadRequestError" => :bad_request,
  "Steroids::Errors::UnauthorizedError" => :unauthorized,
  "Steroids::Errors::ForbiddenError" => :forbidden,
  "Steroids::Errors::NotFoundError" => :not_found,
  "Steroids::Errors::ConflictError" => :conflict,
  "Steroids::Errors::UnprocessableEntityError" => :unprocessable_entity,
  "Steroids::Errors::NotImplementedError" => :not_implemented,
  "BaseErrorTest::CustomTestError" => :unprocessable_entity
)

# Configure ActiveSupport
ActiveSupport.test_order = :random

class ActiveSupport::TestCase
  # Add common test helpers here
end