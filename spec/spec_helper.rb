# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter %r{^/spec/}
    add_filter %r{^/test/}
    enable_coverage :branch
    track_files "lib/**/*.rb"
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] = "test"

require "rails"
require "active_support"
require "active_support/core_ext"
require "active_model"
require "active_job"
require "active_record"
require "active_model_serializers"
require "action_dispatch"

module TestApp
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.logger = Logger.new(nil)
  end
end

Rails.application.initialize!

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :test_records, force: true do |t|
    t.string :name
    t.timestamps
  end
end

unless defined?(Sidekiq)
  module Sidekiq
    def self.server? = false

    class ProcessSet
      def initialize; end
      def any? = false
    end
  end
end

require "steroids"

ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  "Steroids::Errors::BadRequestError" => :bad_request,
  "Steroids::Errors::UnauthorizedError" => :unauthorized,
  "Steroids::Errors::ForbiddenError" => :forbidden,
  "Steroids::Errors::NotFoundError" => :not_found,
  "Steroids::Errors::ConflictError" => :conflict,
  "Steroids::Errors::UnprocessableEntityError" => :unprocessable_content,
  "Steroids::Errors::NotImplementedError" => :not_implemented
)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.filter_run_when_matching :focus

  config.example_status_persistence_file_path = ".rspec_status"
end
