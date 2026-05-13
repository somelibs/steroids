# AGENTS.md - Steroids Rails Enhancement Gem

This file provides guidance to AI Agents when working with code in this repository.

## Overview

Steroids is a Rails enhancement gem that provides powerful abstractions for services, serializers, and various Ruby extensions. It's designed to make Rails applications more maintainable and provide better patterns for common tasks.

## Knowledge base

A structured, machine-readable knowledge base lives at `knowledge/`:

- `knowledge/INDEX.md` — file index + cross-reference graph
- `knowledge/MASTER.md` — product spec, capability inventory, roadmap, acceptance criteria
- `knowledge/biz-*.md` — what Steroids is and who uses it
- `knowledge/ar-*.md` — architecture deep-dives (services, async dispatch, noticable layer, errors/observability, extensions, types/serializers, controllers)
- `knowledge/plans/STATUS.md` — current focus and progress tracking
- `knowledge/plans/@YYYY-MM-DD-NN-*.md` — forward-looking design plans
- `knowledge/wrapups/@YYYY-MM-DD-NN-*.md` — point-in-time engagement records (commit history with context)
- `knowledge/GUIDELINES.md` — project-specific development guidelines (shared baseline lives in `~/.claude/knowledge/GUIDELINES.md`)

This document (AGENTS.md / CLAUDE.md) is the user-facing API tour. Reach for the knowledge base when you need the *why* behind a decision, the cross-cutting picture, or the engagement timeline.

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
    perform_operation
  end
end

# Usage — caller picks per-invocation:
MyService.call(user: current_user, data: params)         # inline
MyService.call_async(user_id: 1, data: params)           # enqueues Steroids::AsyncServiceJob
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

### 4. Async Dispatch

Async-ness is a caller decision, not a service-class property. Every service defines a single `def process`; callers pick `.call` (inline) or `.call_async` (enqueue `Steroids::AsyncServiceJob`).

```ruby
class HeavyService < Steroids::Services::Base
  def process
    heavy_operation
  end
end

HeavyService.call(record_id: 1)        # inline
HeavyService.call_sync(record_id: 1)   # explicit alias for `.call`
HeavyService.call_async(record_id: 1)  # enqueue
```

**No auto-detection.** `.call` never enqueues, `.call_async` never runs inline. (The old `async_process` method + `Sidekiq.server?` heuristic was removed — it produced silent race conditions when the same service was invoked from both sync and async paths.)

For work that **must never** run inline, mark the class with `async_only!`:

```ruby
class MustBeAsync < Steroids::Services::Base
  async_only!  # `.call` / `.call_sync` raise AsyncOnlyError

  def process
    long_running_work
  end
end
```

**Serializability is validated at the call site.** `.call_async` walks the init args before enqueueing and raises `Steroids::Services::Base::NonSerializableArgumentError` with a dotted-path list of every offender (Procs, IO, unpersisted records, anonymous classes). No more silent worker-side `SerializationError`.

```ruby
# ❌ Raises NonSerializableArgumentError listing `handler (Proc)`
HeavyService.call_async(handler: ->(x) { x })

# ✅ Primitives, persisted AR records, GlobalID-aware objects, Symbols, Date/Time
HeavyService.call_async(record_id: 1, persisted_user: user)
```

**Control flags** (`force:`, `skip_callbacks:`) work on both entry points and are forwarded to the worker via the job's `control:` argument in async mode.

**Per-mode success notices.** `success_notice` accepts either a plain String (single message for both modes — the resolver appends `" (async)"` to keep async-side messages accurate) or a Hash keyed by `:sync` / `:async`:

```ruby
class FlagAccountService < Steroids::Services::Base
  success_notice "Account flagged"  # → sync: "Account flagged" · async: "Account flagged (async)"
end

class SendNewsletterService < Steroids::Services::Base
  success_notice sync:  "Newsletter sent to all subscribers",
                 async: "Newsletter queued — subscribers notified shortly"
end
```

If only one mode-key is declared, the missing side falls back to a generic ("Queued for background processing." for async; "<ClassName> succeeded" for sync). In the `service :name, ..., async: true` controller helper, the preview instance the block yields has `dispatch_mode = :async` already set — `service.notice` in the block reads the right message automatically.

### 5. Servicable Methods

Controller integration via `service` macro:

```ruby
class UsersController < ApplicationController
  service :create_user, class_name: "Users::CreateService"
  service :sync_price,  class_name: "SyncPriceService", async: true   # enqueue instead of inline

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

With `async: true`, the helper calls `.call_async` and the block fires immediately after enqueue with a fresh service instance carrying only the class-declared `success_notice`. Worker-side errors do not surface to the request.

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
5. **Success Notice**: Define with `success_notice` (String, or `sync:`/`async:` Hash for per-mode messages)
6. **Callbacks**: Use `before_process` and `after_process` for hooks

## Configuration

Steroids auto-loads with Rails. No configuration needed, but you can customize:

```ruby
# In initializer
Steroids.configure do |config|
  # Configuration options if any
end
```
