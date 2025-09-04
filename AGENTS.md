# AGENTS.md - Steroids Rails Enhancement Gem

This file provides guidance to AI Agents when working with code in this repository.

## Overview

Steroids is a Rails enhancement gem that provides powerful abstractions for services, serializers, and various Ruby extensions. It's designed to make Rails applications more maintainable and provide better patterns for common tasks.

## Project Structure

```
steroids/
├── lib/
│   ├── steroids/
│   │   ├── extensions/       # Ruby core class extensions
│   │   │   ├── array_extension.rb
│   │   │   ├── class_extension.rb
│   │   │   ├── hash_extension.rb
│   │   │   ├── method_extension.rb
│   │   │   ├── module_extension.rb
│   │   │   ├── object_extension.rb
│   │   │   └── proc_extension.rb
│   │   ├── serializers/      # Serialization utilities
│   │   │   ├── base.rb
│   │   │   └── methods.rb
│   │   ├── services/         # Service object pattern
│   │   │   └── base.rb       # Base service class
│   │   ├── support/          # Support modules
│   │   │   ├── magic_class.rb
│   │   │   ├── noticable_methods.rb  # Error/notice handling
│   │   │   └── servicable_methods.rb # Service helpers
│   │   ├── types/           # Type system
│   │   │   ├── base.rb
│   │   │   └── serializable_type.rb
│   │   ├── engine.rb        # Rails engine
│   │   ├── errors.rb        # Error classes
│   │   ├── logger.rb        # Logging utilities
│   │   ├── railtie.rb       # Rails integration
│   │   └── version.rb
│   └── steroids.rb          # Main module
└── app/
    └── jobs/
        └── async_service_job.rb  # Background job for async services
```

## Core Components

### 1. Service Objects (`Steroids::Services::Base`)

The base service class provides a robust pattern for business logic:

```ruby
class MyService < Steroids::Services::Base
  success_notice "Operation completed successfully"

  def initialize(user:, data:)
    @user = user
    @data = data
  end

  def process
    # Synchronous processing
    perform_operation
  end

  # OR for async:
  def async_process
    # Asynchronous processing (runs in background job)
    perform_operation
  end
end

# Usage:
MyService.call(user: current_user, data: params)
```

### 2. Noticable Methods - Error & Notice Handling

**⚠️ CRITICAL: Error Handling Pattern**

The Steroids gem provides a unique error handling system through `NoticableMethods`. This is **NOT** like ActiveRecord's error handling.

#### Key Differences from ActiveRecord:

```ruby
# ❌ WRONG - ActiveRecord style (DOES NOT WORK)
errors.add(:base, "Something went wrong")
errors.add(:field, "is invalid")

# ✅ CORRECT - Steroids style
errors.add("Something went wrong")           # Just the message
errors.add("Failed to sync", exception)      # With optional exception
```

#### NoticableCollection API:

- `errors.add(message, exception = nil)` - Add an error with string message
- `notices.add(message)` - Add a notice
- `errors.any?` - Check if there are errors
- `success?` - Returns true if no errors
- `errors?` - Returns true if errors exist
- `notice` / `message` - Get the full message (errors or success notice)

#### Example in Service:

```ruby
class SyncService < Steroids::Services::Base
  success_notice "Sync completed successfully"

  def process
    begin
      sync_data
    rescue StandardError => e
      errors.add("Failed to sync data", e)  # NOT :base, just the message!
      return
    end

    if validation_failed?
      errors.add("Validation failed")       # Just a string message
    end
  end
end
```

### 3. Service Flow Control

Services provide flow control methods:

```ruby
class MyService < Steroids::Services::Base
  def process
    # Drop/halt execution on error
    drop!("Operation failed") if condition_failed?

    # Or with explicit message:
    drop!(message: "Custom failure message")

    # Errors are automatically collected
    errors.add("This failed")
    # If errors.any? is true after process, service automatically drops
  end

  # Callbacks
  before_process :validate_inputs
  after_process :cleanup

  # Rescue and ensure hooks
  def rescue!(exception)
    # Handle exceptions
  end

  def ensure!
    # Always runs
  end
end
```

### 4. Async Services

Services can run asynchronously with Sidekiq:

```ruby
class AsyncService < Steroids::Services::Base
  # Use async_process instead of process
  def async_process
    heavy_operation
  end
end

# Runs in background:
AsyncService.call(serializable: 'data', only: true)

# Force synchronous:
AsyncService.call(data: data, async: false)
```

**Important**: Async services require serializable parameters (strings, numbers, hashes, arrays - no AR objects).

### 5. Servicable Methods

Controller integration via `service` macro:

```ruby
class UsersController < ApplicationController
  service :create_user, class_name: "Users::CreateService"

  def create
    create_user(user_params) do |service|
      if service.success?
        redirect_to user_path, notice: service.notice
      else
        render :new, alert: service.errors.full_messages
      end
    end
  end
end
```

### 6. Type System

Steroids provides runtime type checking:

```ruby
# Type validation
value.typed!(String)  # Raises if not a String
value.typed!(Integer)

# Type casting
STATES = %i[draft published archived]
state = STATES.cast(:draft)  # Returns :draft or raises if invalid
```

### 7. Extensions

Various Ruby core extensions:

```ruby
# Hash extensions
hash.serializable?  # Check if can be serialized
hash.deep_serialize # Deep serialization

# Object extensions
object.send_apply(method, *args)  # Safe send with fallback
object.try_method(:method_name)   # Try to get method object

# Array extensions
array.cast(value)  # Ensure value is in array
```

## Common Patterns

### Service with Transaction

```ruby
class CreateOrderService < Steroids::Services::Base
  success_notice "Order created successfully"

  def initialize(user:, items:)
    @user = user
    @items = items
  end

  def process
    # Automatically wrapped in transaction
    order = Order.create!(user: @user)

    @items.each do |item|
      order.line_items.create!(item)
    end

    order
  rescue ActiveRecord::RecordInvalid => e
    errors.add("Failed to create order", e)  # Remember: just strings!
  end
end
```

### Service with Validation

```ruby
class UpdateProfileService < Steroids::Services::Base
  def initialize(user:, params:)
    @user = user
    @params = params
  end

  def process
    unless @params[:email].present?
      errors.add("Email is required")
      return
    end

    @user.update!(email: @params[:email])
  rescue => e
    errors.add("Update failed", e)
  end
end
```

## Testing Services

```ruby
# RSpec example
RSpec.describe MyService do
  subject { described_class.new(param: value) }

  context "when successful" do
    it "returns success" do
      subject.call
      expect(subject).to be_success
      expect(subject.notice).to eq("Operation completed successfully")
    end
  end

  context "when failed" do
    it "has errors" do
      subject.call
      expect(subject).to be_errors
      expect(subject.errors.full_messages).to include("Error message")
    end
  end
end
```

## Important Notes

1. **Error Handling**: Always use `errors.add("message")` not `errors.add(:base, "message")`
2. **Async Services**: Parameters must be serializable
3. **Transactions**: Services are wrapped in transactions by default
4. **Flow Control**: Use `drop!` to halt execution with error
5. **Success Notice**: Define with `success_notice` class method
6. **Callbacks**: Use `before_process` and `after_process` for hooks

## Configuration

Steroids auto-loads with Rails. No configuration needed, but you can customize:

```ruby
# In initializer
Steroids.configure do |config|
  # Configuration options if any
end
```
