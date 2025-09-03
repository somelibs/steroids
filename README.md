# Steroids

[![Gem Version](https://img.shields.io/badge/version-1.6.0-green)](https://rubygems.org/gems/steroids)
[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207.1-red)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.0-red)](https://www.ruby-lang.org/)
[![Tests](https://img.shields.io/badge/tests-78%20passing-brightgreen)](https://github.com/somelibs/steroids)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE.md)

**Steroids** supercharges your Rails applications with powerful service objects, enhanced error handling, and useful Ruby extensions. Build maintainable, testable business logic with a battle-tested service layer pattern.

## Table of Contents

- [Getting Started](#getting-started)
- [Service Objects](#service-objects)
- [Error Handling](#error-handling)
- [Controller Integration](#controller-integration)
- [Async Services](#async-services)
- [Serializers (Deprecated)](#serializers-deprecated)
- [Error Classes](#error-classes)
- [Logger](#logger)
- [Extensions](#extensions)
- [Testing](#testing)
- [Configuration](#configuration)
- [Contributing](#contributing)
- [License](#license)

## Getting Started

### Requirements

- Ruby 3.0+
- Rails 7.1+
- Sidekiq (optional, for async services)

### Installation

Add Steroids to your application's Gemfile:

```ruby
# From GitHub (recommended during active development)
gem 'steroids', git: 'git@github.com:somelibs/steroids.git', branch: 'master'

# Or from RubyGems (when published)
gem 'steroids'
```

And then execute:

```bash
$ bundle install
```

## Service Objects

Steroids provides a powerful service object pattern for encapsulating business logic.

### Basic Service

```ruby
class CreateUserService < Steroids::Services::Base
  success_notice "User created successfully"

  def initialize(name:, email:, role: 'user')
    @name = name
    @email = email
    @role = role
  end

  def process
    user = User.create!(
      name: @name,
      email: @email,
      role: @role
    )
    
    UserMailer.welcome(user).deliver_later
    user  # Return value becomes the service call result
  rescue ActiveRecord::RecordInvalid => e
    errors.add("Failed to create user: #{e.message}", e)
    nil  # Return nil on failure
  end
end
```

### Usage Patterns

```ruby
# Method 1: Direct call with block (RECOMMENDED for controllers)
CreateUserService.call(name: "John", email: "john@example.com") do |service|
  if service.success?
    redirect_to users_path, notice: service.notice
  else
    flash.now[:alert] = service.errors.full_messages
    render :new
  end
end

# Method 2: Get return value directly
user = CreateUserService.call(name: "John", email: "john@example.com")
# user is the return value from process method (User object or nil)

# Method 3: Check service instance
service = CreateUserService.new(name: "John", email: "john@example.com")
result = service.call

if service.success?
  puts service.notice  # => "User created successfully"
  # result contains the User object
else
  puts service.errors.full_messages
  # result is nil
end
```

### Important Behaviors

**Block Parameters**: When using blocks, the service instance is passed as the first parameter:
```ruby
CreateUserService.call(name: "John") do |service|
  # service contains the service instance with noticable methods
  if service.success?
    # handle success
  end
end
```

**Return Values**: 
- Without a block: `call` returns the result of the `process` method
- With a block: `call` returns the result of the `process` method, and yields the service instance to the block

```ruby
# Without block - returns process result directly
user = CreateUserService.call(name: "John", email: "john@example.com")
# user is the User object (or nil if failed)

# With block - still returns process result, but yields service for status checking
user = CreateUserService.call(name: "John", email: "john@example.com") do |service|
  if service.errors?
    # Handle errors using service.errors
  end
end
# user is still the User object (or nil if failed)
```

### Service with Validations

```ruby
class UpdateProfileService < Steroids::Services::Base
  success_notice "Profile updated"

  def initialize(user:, params:)
    @user = user
    @params = params
  end

  private

  def process
    validate_params!
    @user.update!(@params)
  rescue StandardError => e
    errors.add("Update failed: #{e.message}", e)
  end

  def validate_params!
    if @params[:email].blank?
      errors.add("Email cannot be blank")
      drop!  # Halts execution
    end
  end
end
```

### Service Callbacks

```ruby
class ProcessPaymentService < Steroids::Services::Base
  before_process :validate_payment
  after_process :send_receipt

  def initialize(order:, payment_method:)
    @order = order
    @payment_method = payment_method
  end

  def process
    @payment = Payment.create!(
      order: @order,
      amount: @order.total,
      method: @payment_method
    )
  end

  private

  def validate_payment
    drop!("Invalid payment amount") if @order.total <= 0
  end

  def send_receipt(payment)
    PaymentMailer.receipt(payment).deliver_later
  end
end
```

## Error Handling

**⚠️ IMPORTANT:** Steroids uses a different error handling pattern than ActiveRecord.

### Correct Usage

```ruby
# ✅ CORRECT - Steroids pattern
errors.add("Something went wrong")
errors.add("Operation failed", exception)
notices.add("Processing started")
```

### Incorrect Usage

```ruby
# ❌ WRONG - ActiveRecord pattern (will NOT work)
errors.add(:base, "Something went wrong")
errors.add(:field, "is invalid")
```

### Error Flow Control

```ruby
class ComplexService < Steroids::Services::Base
  def process
    # Method 1: Add error and return
    if condition_failed?
      errors.add("Condition not met")
      return
    end

    # Method 2: Drop with message (halts execution)
    drop!("Critical failure") if critical_error?

    # Method 3: Automatic drop on errors
    validate_something  # adds errors
    # Service automatically drops if errors.any? is true
  end

  def rescue!(exception)
    # Handle any uncaught exceptions
    logger.error "Service failed: #{exception.message}"
    errors.add("An unexpected error occurred")
  end

  def ensure!
    # Always runs, even on failure
    cleanup_resources
  end
end
```

## Controller Integration

### Using the Service Macro

```ruby
class UsersController < ApplicationController
  # Define service with custom class
  service :create_user, class_name: "Users::CreateService"
  service :update_user, class_name: "Users::UpdateService"

  def create
    create_user(user_params) do |service|
      if service.success?
        redirect_to users_path, notice: service.notice
      else
        @user = User.new(user_params)
        flash.now[:alert] = service.errors.full_messages
        render :new
      end
    end
  end

  def update
    update_user(user: @user, params: user_params) do |service|
      if service.success?
        redirect_to @user, notice: service.notice
      else
        flash.now[:alert] = service.errors.full_messages
        render :edit
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
```

### Direct Service Call

```ruby
class OrdersController < ApplicationController
  def complete
    service = CompleteOrderService.call(order: @order, payment_id: params[:payment_id])
    
    respond_to do |format|
      if service.success?
        format.html { redirect_to @order, notice: service.notice }
        format.json { render json: { message: service.notice }, status: :ok }
      else
        format.html { redirect_to @order, alert: service.errors.full_messages }
        format.json { render json: { errors: service.errors.to_a }, status: :unprocessable_entity }
      end
    end
  end
end
```

## Async Services

Services can run asynchronously using Sidekiq. **Important:** In development, test environments, and Rails console, async services automatically run synchronously for easier debugging.

### Defining an Async Service

```ruby
class SendNewsletterService < Steroids::Services::Base
  success_notice "Newsletter sent to all subscribers"

  def initialize(subject:, content:)
    @subject = subject
    @content = content
  end

  # Use async_process instead of process
  def async_process
    User.subscribed.find_each do |user|
      NewsletterMailer.weekly(user, @subject, @content).deliver_now
    end
  rescue StandardError => e
    errors.add("Newsletter delivery failed", e)
  end
end

# Behavior varies by environment:
# - Production with Sidekiq running: Runs in background
# - Development/Test/Console: Runs synchronously (immediate execution)
SendNewsletterService.call(subject: "Weekly Update", content: "...")

# Force synchronous execution in any environment
SendNewsletterService.call(subject: "Test", content: "...", async: false)
```

### Async Execution Logic

The service automatically determines execution mode based on:

```ruby
# Runs async when ALL conditions are met:
# 1. Sidekiq is running (workers available)
# 2. NOT in Rails console
# 3. NOT in development (unless Sidekiq is running)
# 4. async: true (default)

# Otherwise runs synchronously for easier debugging
```

### Important Notes for Async Services

1. **Parameters must be serializable** (strings, numbers, hashes, arrays)
2. **Don't pass ActiveRecord objects** - pass IDs instead
3. **Use `async_process` method** instead of `process`
4. **Runs via `AsyncServiceJob`** with Sidekiq in production
5. **Auto-synchronous in dev/test** for easier debugging

```ruby
# ❌ WRONG - AR object won't serialize
AsyncService.call(user: current_user)

# ✅ CORRECT - Pass serializable data
AsyncService.call(user_id: current_user.id)
```

## Serializers (Deprecated)

> **⚠️ DEPRECATION WARNING:** The Serializers module will be removed in the next major version. Consider using [ActiveModel::Serializer](https://github.com/rails-api/active_model_serializers) or [Blueprinter](https://github.com/procore/blueprinter) directly.

Steroids provides a thin wrapper around ActiveModel::Serializer:

```ruby
class UserSerializer < Steroids::Serializers::Base
  attributes :id, :name, :email, :role
  has_many :posts
  
  def custom_attribute
    object.some_computed_value
  end
end

# Usage
serializer = UserSerializer.new(user)
serializer.to_json
```

## Error Classes

Steroids provides a comprehensive error hierarchy with HTTP status codes and logging capabilities.

### Base Error Class

```ruby
class CustomError < Steroids::Errors::Base
  self.default_message = "Something went wrong"
  self.default_status = :internal_server_error
end

# Usage with various options
raise CustomError.new("Specific error message")
raise CustomError.new(
  message: "Error occurred",
  status: :bad_request,
  code: "ERR_001",
  cause: original_exception,
  context: { user_id: 123 },
  log: true  # Automatically log the error
)

# Access error properties
begin
  # some code
rescue CustomError => e
  e.message     # Error message
  e.status      # HTTP status symbol
  e.code        # Custom error code
  e.cause       # Original exception if any
  e.context     # Additional context
  e.timestamp   # When the error occurred
end
```

### Pre-defined HTTP Error Classes

```ruby
# 400 Bad Request
raise Steroids::Errors::BadRequestError.new("Invalid parameters")

# 401 Unauthorized
raise Steroids::Errors::UnauthorizedError.new("Please login")

# 403 Forbidden
raise Steroids::Errors::ForbiddenError.new("Access denied")

# 404 Not Found
raise Steroids::Errors::NotFoundError.new("Resource not found")

# 409 Conflict
raise Steroids::Errors::ConflictError.new("Resource already exists")

# 422 Unprocessable Entity
raise Steroids::Errors::UnprocessableEntityError.new("Validation failed")

# 500 Internal Server Error
raise Steroids::Errors::InternalServerError.new("Server error")

# 501 Not Implemented
raise Steroids::Errors::NotImplementedError.new("Feature coming soon")
```

### Error Serialization

Errors can be serialized for API responses:

```ruby
class ApiController < ApplicationController
  rescue_from Steroids::Errors::Base do |error|
    render json: error.to_json, status: error.status
  end
end
```

### Error Context and Logging

```ruby
# Add context for debugging
error = Steroids::Errors::BadRequestError.new(
  "Invalid input",
  context: {
    user_id: current_user.id,
    params: params.to_unsafe_h,
    timestamp: Time.current
  },
  log: true  # Will automatically log with Steroids::Logger
)

# Manual logging
error.log!  # Logs the error with full backtrace
```

## Logger

Steroids provides an enhanced logger with colored output, backtrace formatting, and error notification support.

### Basic Usage

```ruby
# Simple logging
Steroids::Logger.print("Operation completed")
Steroids::Logger.print("Warning message", verbosity: :concise)

# Logging exceptions
begin
  risky_operation
rescue => e
  Steroids::Logger.print(e)  # Automatically detects error level
end
```

### Verbosity Levels

```ruby
# Full backtrace (default for exceptions)
Steroids::Logger.print(exception, verbosity: :full)

# Concise backtrace (app code only)
Steroids::Logger.print(exception, verbosity: :concise)

# No backtrace
Steroids::Logger.print(exception, verbosity: :none)
```

### Format Options

```ruby
# Decorated output with colors (default)
Steroids::Logger.print("Message", format: :decorated)

# Raw output without colors
Steroids::Logger.print("Message", format: :raw)
```

### Automatic Log Levels

The logger automatically determines the appropriate log level:

- **`:error`** - For `StandardError`, `InternalServerError`, `GenericError`
- **`:warn`** - For other `Steroids::Errors::Base` subclasses
- **`:info`** - For regular messages

### Error Notifications

Configure a notifier to receive alerts for errors:

```ruby
# In an initializer
Steroids::Logger.notifier = lambda do |error|
  # Send to error tracking service
  Bugsnag.notify(error)
  # Or send to Slack
  SlackNotifier.alert(error.message)
end
```

### Colored Output

The logger uses Rainbow for colored terminal output:

- 🔴 **Red** - Errors
- 🟡 **Yellow** - Warnings
- 🟢 **Green** - Info messages
- 🟣 **Magenta** - Error class names and quiet logs

### Integration with Services

Services automatically use the logger for error handling:

```ruby
class MyService < Steroids::Services::Base
  def process
    Steroids::Logger.print("Starting process")
    
    perform_operation
    
    Steroids::Logger.print("Process completed")
  rescue => e
    Steroids::Logger.print(e)  # Full error logging with backtrace
    errors.add("Process failed", e)
  end
end
```

## Extensions

Steroids provides useful extensions to Ruby core classes.

### Type Checking

```ruby
# Ensure type at runtime
def process_name(name)
  name.typed!(String)  # Raises TypeError if not a String
  name.upcase
end

# Type casting with enums
STATUSES = %i[draft published archived]
status = STATUSES.cast(:published)  # Returns :published
status = STATUSES.cast(:invalid)    # Raises error
```

### Hash Extensions

```ruby
# Check if hash is serializable
params.serializable?  # => true/false

# Deep serialize for storage
data = { user: { name: "John", tags: ["ruby", "rails"] } }
serialized = data.deep_serialize
```

### Safe Method Calls

```ruby
# Safe send with fallback
object.send_apply(:optional_method, arg1, arg2)

# Try to get method object
method_obj = object.try_method(:method_name)
```

## Testing

### RSpec Examples

```ruby
RSpec.describe CreateUserService do
  describe "#call" do
    context "with valid params" do
      subject { described_class.call(name: "John", email: "john@test.com") }

      it "succeeds" do
        expect(subject).to be_success
        expect(subject.errors).not_to be_any
      end

      it "creates a user" do
        expect { subject }.to change(User, :count).by(1)
      end

      it "returns success notice" do
        expect(subject.notice).to eq("User created successfully")
      end
    end

    context "with invalid params" do
      subject { described_class.call(name: "", email: "invalid") }

      it "fails" do
        expect(subject).to be_errors
        expect(subject).not_to be_success
      end

      it "returns error messages" do
        expect(subject.errors.full_messages).to include(/failed/i)
      end
    end
  end
end
```

### Testing Async Services

```ruby
RSpec.describe AsyncNewsletterService do
  it "enqueues job" do
    expect {
      described_class.call(subject: "Test", content: "Content")
    }.to have_enqueued_job(AsyncServiceJob)
  end

  it "processes synchronously when forced" do
    service = described_class.call(subject: "Test", content: "Content", async: false)
    expect(service).to be_success
  end
end
```

## Configuration

### Transaction Wrapping

Services are wrapped in database transactions by default:

```ruby
class MyService < Steroids::Services::Base
  # Disable transaction wrapping for this service
  self.wrap_in_transaction = false
  
  def process
    # Not wrapped in transaction
  end
end
```

### Callback Configuration

```ruby
class MyService < Steroids::Services::Base
  # Skip all callbacks
  self.skip_callbacks = true
  
  # Or skip per invocation
  def process
    MyService.call(data: data, skip_callbacks: true)
  end
end
```

## Development

### Local Development

When developing Steroids locally alongside a Rails application, you can use Bundler's local gem override:

```bash
# Point Bundler to your local Steroids repository
$ bundle config local.steroids /path/to/local/steroids

# Example:
$ bundle config local.steroids ~/Projects/steroids

# Verify the configuration
$ bundle config
# Should show: local.steroids => "/path/to/local/steroids"

# Install/update dependencies
$ bundle install
```

Now your Rails app will use the local version of Steroids. Any changes you make to the gem will be reflected immediately (after restarting Rails).

To remove the local override:

```bash
$ bundle config --delete local.steroids
$ bundle install
```

### Running Tests

Steroids uses Minitest for testing. The test suite includes comprehensive coverage of:
- Service objects and lifecycle
- Noticable methods (error/notice handling)
- Controller integration (servicable methods)
- Error classes and logging
- Async services

#### Run All Tests

```bash
# Using Rake (recommended)
$ bundle exec rake test

# With verbose output
$ bundle exec rake test TESTOPTS="--verbose"
```

#### Run Specific Test Files

```bash
# Test services
$ bundle exec rake test TEST=test/services/base_service_test.rb
$ bundle exec rake test TEST=test/services/async_service_test.rb

# Test support modules
$ bundle exec rake test TEST=test/support/noticable_methods_test.rb
$ bundle exec rake test TEST=test/support/servicable_methods_test.rb

# Test errors
$ bundle exec rake test TEST=test/errors/base_error_test.rb

# Main module test
$ bundle exec rake test TEST=test/steroids_test.rb
```

#### Run Tests by Pattern

```bash
# Run all service tests
$ bundle exec rake test TEST="test/services/*"

# Run multiple specific tests
$ bundle exec rake test TEST="test/services/base_service_test.rb,test/support/noticable_methods_test.rb"
```

#### Test Coverage

To check test coverage (requires simplecov gem):

```bash
# Add to Gemfile (test group)
gem 'simplecov', require: false

# Add to test_helper.rb (at the top)
require 'simplecov'
SimpleCov.start 'rails'

# Run tests and generate coverage report
$ bundle exec rake test
# Coverage report will be in coverage/index.html
```

## Troubleshooting

### Common Issues

**Issue:** `TypeError: Expected String instance`
**Solution:** Ensure you're using `errors.add("message")` not `errors.add(:symbol, "message")`

**Issue:** Async service not running
**Solution:** Ensure Sidekiq is running and parameters are serializable

**Issue:** Transaction rollback not working
**Solution:** Ensure `wrap_in_transaction` is not disabled

## Roadmap

- [ ] Standalone testing with dummy Rails app
- [ ] Generator for service objects
- [ ] Built-in metrics and instrumentation
- [ ] Service composition patterns
- [ ] Enhanced async job features

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/somelibs/steroids.

## Disclaimer

This gem is under active development and may not strictly follow SemVer. Use at your own risk in production environments.

## Credits

Created and maintained by Paul R.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.md).