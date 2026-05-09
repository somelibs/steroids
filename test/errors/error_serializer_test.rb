require "test_helper"

class ErrorSerializerTest < ActiveSupport::TestCase
  def serialize(error)
    Steroids::ErrorSerializer.new(error).serializable_hash
  end

  def with_rails_env(env)
    original = Rails.env
    Rails.define_singleton_method(:env) { ActiveSupport::EnvironmentInquirer.new(env) }
    yield
  ensure
    Rails.define_singleton_method(:env) { original }
  end

  # Regression: a previous declaration
  #   `attributes :exception, :message, if: -> { Rails.env.development? }`
  # silently overrode the unconditional `attribute :message` above it (AMS uses
  # the last attribute declaration), causing every error response in production
  # to ship without a `message` field. Consumers like Bernstein then rendered
  # empty alert banners on failed login attempts.
  test "production env: message attribute is included" do
    error = Steroids::Errors::UnauthorizedError.new(message: "Unauthorized.")

    with_rails_env("production") do
      hash = serialize(error)
      assert_includes hash.keys, :message
      assert_equal "Unauthorized.", hash[:message]
    end
  end

  test "production env: exception attribute is omitted (dev-only)" do
    error = Steroids::Errors::UnauthorizedError.new(message: "Unauthorized.")

    with_rails_env("production") do
      hash = serialize(error)
      assert_not_includes hash.keys, :exception
    end
  end

  test "development env: includes both message and exception" do
    error = Steroids::Errors::BadRequestError.new(
      message: "Invalid input",
      cause: StandardError.new("upstream failure")
    )

    with_rails_env("development") do
      hash = serialize(error)
      assert_includes hash.keys, :message
      assert_includes hash.keys, :exception
      assert_equal "StandardError", hash[:exception]
      assert_match(/Invalid input/, hash[:message])
    end
  end

  test "core envelope (id, code, status, errors, timestamp) is always present" do
    error = Steroids::Errors::NotFoundError.new(message: "Not here")

    with_rails_env("production") do
      hash = serialize(error)
      [:id, :code, :status, :errors, :timestamp].each do |key|
        assert_includes hash.keys, key, "expected #{key.inspect} to be serialized"
      end
    end
  end
end
