# Steroids

[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207.1-red)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.0-red)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE.md)

**Steroids** supercharges your Rails applications with powerful service objects, enhanced error handling, and useful Ruby extensions. Build maintainable, testable business logic with a battle-tested service layer pattern.

## Table of Contents

- [Getting Started](#getting-started)
- [Service Objects](#service-objects)
- [Error Handling](#error-handling)
- [Controller Integration](#controller-integration)
- [Async Services](#async-services)
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
    user
  rescue ActiveRecord::RecordInvalid => e
    errors.add("Failed to create user: #{e.message}", e)
  end
end

# Usage
service = CreateUserService.call(name: "John", email: "john@example.com")

if service.success?
  puts service.notice  # => "User created successfully"
else
  puts service.errors.full_messages  # => "Failed to create user: ..."
end
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

Services can run asynchronously using Sidekiq.

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

# This runs in background
SendNewsletterService.call(subject: "Weekly Update", content: "...")

# Force synchronous execution
SendNewsletterService.call(subject: "Test", content: "...", async: false)
```

### Important Notes for Async Services

1. **Parameters must be serializable** (strings, numbers, hashes, arrays)
2. **Don't pass ActiveRecord objects** - pass IDs instead
3. **Use `async_process` method** instead of `process`
4. **Runs via `AsyncServiceJob`** with Sidekiq

```ruby
# ❌ WRONG - AR object won't serialize
AsyncService.call(user: current_user)

# ✅ CORRECT - Pass serializable data
AsyncService.call(user_id: current_user.id)
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

When developing locally with a Rails application:

```bash
# Point to local gem development
$ bundle config local.steroids /path/to/local/steroids
```

### Running Tests

```bash
$ bundle exec rake test
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