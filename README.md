# Steroids

[![Gem Version](https://img.shields.io/badge/version-1.6.1-green)](https://rubygems.org/gems/steroids)
[![Rails](https://img.shields.io/badge/Rails-%3E%3D%207-red)](https://rubyonrails.org/)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.3-red)](https://www.ruby-lang.org/)
[![Specs](https://img.shields.io/badge/specs-RSpec-brightgreen)](https://github.com/wandernb/steroids)
[![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE.md)

**Steroids** supercharges Rails applications with a battle-tested **service object** layer, a unified **notice / error** model, a rich **HTTP error hierarchy**, a colorful **logger**, and a handful of pragmatic **Ruby core extensions**. The goal: push business logic out of controllers and models into small, testable, composable objects — without ceremony.

```ruby
class CreateInvoiceService < Steroids::Services::Base
  success_notice "Invoice created"

  def initialize(account:, amount:)
    @account = account
    @amount  = amount
  end

  def process
    Invoice.create!(account: @account, amount: @amount)
  rescue ActiveRecord::RecordInvalid => e
    errors.add("Could not create invoice", e)
  end
end

CreateInvoiceService.call(account: account, amount: 4200) do |service|
  if service.success?
    redirect_to invoices_path, notice: service.notice
  else
    render :new, alert: service.errors.full_messages
  end
end
```

---

## Table of Contents

- [Why Steroids?](#why-steroids)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Installation](#installation)
  - [Setup](#setup)
- [Service Objects](#service-objects)
  - [Anatomy of a Service](#anatomy-of-a-service)
  - [Calling a Service](#calling-a-service)
  - [Return Values & Error Propagation](#return-values--error-propagation)
  - [Flow Control: `drop!` and `force`](#flow-control-drop-and-force)
  - [Callbacks & Lifecycle Hooks](#callbacks--lifecycle-hooks)
  - [Transactions](#transactions)
  - [Dos and Don'ts](#service-dos-and-donts)
- [Notices & Errors (Noticable)](#notices--errors-noticable)
  - [The Noticable API](#the-noticable-api)
  - [Steroids vs ActiveRecord Errors](#steroids-vs-activerecord-errors)
  - [Dos and Don'ts](#noticable-dos-and-donts)
- [Controller Integration](#controller-integration)
  - [The `service` Macro](#the-service-macro)
  - [Block Form & `flash_key`](#block-form--flash_key)
  - [Direct Calls](#direct-calls)
  - [`respond_with` & Serializers](#respond_with--serializers)
  - [Dos and Don'ts](#controller-dos-and-donts)
- [Async Dispatch](#async-dispatch)
  - [`call` vs `call_async`](#call-vs-call_async)
  - [Background-only Services (`async_only!`)](#background-only-services-async_only)
  - [Per-mode Success Notices](#per-mode-success-notices)
  - [Serializability Validation](#serializability-validation)
  - [Control Flags](#control-flags)
- [Steroids Errors](#steroids-errors)
  - [The Base Error](#the-base-error)
  - [HTTP Error Classes](#http-error-classes)
  - [Serializing Errors for APIs](#serializing-errors-for-apis)
  - [Observability Seam](#observability-seam)
  - [Dos and Don'ts](#error-dos-and-donts)
- [Logger](#logger)
- [Extensions](#extensions)
  - [Object](#object-extensions)
  - [Array](#array-extensions)
  - [Hash](#hash-extensions)
  - [Class, Method & Module](#class-method--module-extensions)
  - [Dos and Don'ts](#extension-dos-and-donts)
- [Types](#types)
- [Serializers (Deprecated)](#serializers-deprecated)
- [Testing](#testing)
- [Configuration](#configuration)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Why Steroids?

Rails gives you Models, Views, and Controllers. It does **not** give you a home for *application logic* — the multi-step operations that touch several models, call external services, send mail, and need consistent error reporting. That logic tends to leak into fat controllers and god models.

Steroids gives that logic a home:

- **Service objects** — one public entry point (`process`), automatic transaction wrapping, lifecycle callbacks, and structured error capture.
- **One notice model everywhere** — services, controllers, and errors all speak the same `errors` / `notices` / `notice` / `success?` vocabulary.
- **Sync or async is a caller decision** — the *same* service runs inline with `.call` or in the background with `.call_async`. No duplicated classes.
- **A real error hierarchy** — HTTP-aware error classes that serialize to JSON, carry context, and plug into your observability tooling.
- **Quality-of-life extensions** — runtime type assertions, safe dispatch, deep serialization checks, and more.

---

## Getting Started

### Requirements

- **Ruby** >= 3.3
- **Rails** >= 7
- An **ActiveJob** backend (Sidekiq, GoodJob, Solid Queue, …) — only required if you use async dispatch.

### Installation

Add Steroids to your `Gemfile`:

```ruby
# From RubyGems
gem "steroids"

# Or track the repository directly
gem "steroids", git: "https://github.com/wandernb/steroids.git", branch: "master"
```

Then:

```bash
$ bundle install
```

Steroids is a Rails engine and auto-loads itself — the core extensions (`typed!`, `cast`, `send_apply`, …) and the `Steroids::*` namespace are available everywhere with no initializer required.

### Setup

Service objects, errors, the logger, and the extensions work out of the box. To use the **controller toolkit** (the `service` macro, `respond_with`, serializer defaults), include the controller concern in your base controller:

```ruby
class ApplicationController < ActionController::Base
  include Steroids::Controllers::Methods
end
```

> If you only want the `service` macro and nothing else, include the narrower
> `Steroids::Support::ServicableMethods` instead.

---

## Service Objects

A **service** encapsulates one business operation. Subclass `Steroids::Services::Base`, define `initialize` to receive your inputs, and define `process` to do the work.

### Anatomy of a Service

```ruby
class CreateUserService < Steroids::Services::Base
  success_notice "User created successfully"

  # Inputs come in as keyword args. Stash them in ivars.
  def initialize(name:, email:, role: "member")
    @name  = name
    @email = email
    @role  = role
  end

  # `process` is the single entry point. Its return value becomes the
  # result of `.call`. Raise, `drop!`, or add to `errors` to signal failure.
  def process
    user = User.create!(name: @name, email: @email, role: @role)
    UserMailer.welcome(user).deliver_later
    user
  rescue ActiveRecord::RecordInvalid => e
    errors.add("Failed to create user", e)
  end
end
```

Key rules:

- **`process` is required.** It is the *only* method Steroids calls. Everything else is your own helper code.
- **The return value of `process` is the return value of `.call`** (on success).
- **A service "fails"** when it accumulates entries in `errors`, calls `drop!`, or lets an exception escape `process`.

### Calling a Service

There are three equivalent entry points. They differ only in *how* the operation is dispatched, not in what `process` does.

```ruby
# Inline (synchronous). Blocks until `process` returns.
CreateUserService.call(name: "Ada", email: "ada@example.com")

# Explicit synchronous alias — reads better at call sites that also use call_async.
CreateUserService.call_sync(name: "Ada", email: "ada@example.com")

# Background (enqueues Steroids::AsyncServiceJob). Returns the job handle.
CreateUserService.call_async(name: "Ada", email: "ada@example.com")
```

The **recommended** pattern — especially in controllers — passes a block. The block receives the finished service instance, so you can branch on `success?`:

```ruby
CreateUserService.call(name: "Ada", email: "ada@example.com") do |service|
  if service.success?
    redirect_to users_path, notice: service.notice
  else
    flash.now[:alert] = service.errors.full_messages
    render :new
  end
end
```

The block's arity is adaptive — Steroids hands it whatever it declares. All of these work:

```ruby
.call(...) { |service| ... }                 # just the service
.call(...) { |service, outcome| ... }        # service + process return value
.call(...) { |service, flash_key:| ... }     # service + :notice/:alert key
```

### Return Values & Error Propagation

This is the single most important behavior to understand:

| Call style | On success | On failure |
|---|---|---|
| **With a block** | block runs; `.call` returns the `process` value | block runs (inspect `service.errors`); **no exception raised** |
| **Without a block** | `.call` returns the `process` value | **raises** `Steroids::Support::NoticableMethods::RuntimeException` |

```ruby
# WITH a block — failures are handed to you, never raised.
CreateUserService.call(name: "") do |service|
  service.errors? # => true; you decide what to do
end

# WITHOUT a block — success returns the value, failure RAISES.
user = CreateUserService.call(name: "Ada", email: "ada@example.com")
# `user` is the created User on success.
# If the service had errored, the line above would have raised instead.
```

Use the **block form** when you want to handle both branches yourself (controllers, UI). Use the **block-less form** when a failure genuinely *is* exceptional and you want it to bubble up to a `rescue_from` or a background-job retry.

### Flow Control: `drop!` and `force`

Call `drop!` inside `process` (or a callback) to halt execution immediately. It raises an internal control exception that Steroids converts into a notice — your `process` stops where it stands.

```ruby
def process
  drop!("Account is locked") if @account.locked?

  # ...only reached if the account is not locked
  @account.charge!(@amount)
end
```

`drop!` accepts a positional message or a `message:` keyword:

```ruby
drop!("Invalid amount")
drop!(message: "Invalid amount")
drop!                          # drops using whatever is already in `errors`
```

The `force: true` control flag **disables `drop!`** for that invocation — the service keeps going past any `drop!` call. Use it sparingly, for replays or admin overrides:

```ruby
ChargeService.call(account: account, amount: 0, force: true) # drop! becomes a no-op
```

### Callbacks & Lifecycle Hooks

```ruby
class ProcessPaymentService < Steroids::Services::Base
  before_process :validate_amount
  after_process  :send_receipt

  def initialize(order:)
    @order = order
  end

  def process
    Payment.create!(order: @order, amount: @order.total)
  end

  # Catches any exception that escapes `process`. Defining this (or passing a
  # block to `.call`) means exceptions are captured into `errors` instead of
  # re-raised.
  def rescue!(exception)
    errors.add("Payment failed", exception)
  end

  # Always runs — success or failure.
  def ensure!
    @order.touch(:payment_attempted_at)
  end

  private

  def validate_amount
    drop!("Order total must be positive") if @order.total <= 0
  end

  def send_receipt(payment)
    PaymentMailer.receipt(payment).deliver_later
  end
end
```

Hooks at a glance:

- `before_process :method` — runs before `process` (multiple allowed, in order).
- `after_process :method` — runs after a successful `process`; receives the return value.
- `rescue!(exception)` — optional; captures escaped exceptions into `errors`.
- `ensure!` — optional; always runs last.

Skip *all* callbacks for one invocation with `skip_callbacks: true`:

```ruby
ProcessPaymentService.call(order: order, skip_callbacks: true)
```

### Transactions

Every service wraps `process` in an `ActiveRecord::Base.transaction` by default — so a `drop!` or a raised error rolls back partial writes.

For services that primarily talk to a **third party** (payment gateway, external API), opt out so a slow network round-trip doesn't hold a database connection open:

```ruby
class SyncPriceService < Steroids::Services::Base
  wrap_in_transaction false   # class-level opt-out

  def process
    price.gateway.publish_once!
  end
end
```

> ⚠️ Use the **class macro** `wrap_in_transaction false`. There is no
> `self.wrap_in_transaction = false` instance setter.

<a name="service-dos-and-donts"></a>
### Dos and Don'ts

✅ **Do** keep one public operation per service, exposed through `process`.

✅ **Do** add domain failures with `errors.add("message", exception)` and let Steroids decide whether to raise.

✅ **Do** pass a block in controllers so failures don't raise mid-request.

❌ **Don't** call `process` directly — always go through `.call` / `.call_async`. Direct calls skip transactions, callbacks, and error capture.

❌ **Don't** rely on the block-less `.call` to "return nil on failure" — it **raises**. Use a block if you want to inspect errors.

❌ **Don't** `rescue Exception => e; nil` inside `process` to silence failures — add them to `errors` so the caller can see them.

---

## Notices & Errors (Noticable)

Every service (and anything that includes `Steroids::Support::NoticableMethods`) carries two collections — `errors` and `notices` — and a resolved `notice` message. This is **not** ActiveModel's errors API; it is simpler and string-based.

### The Noticable API

```ruby
# Add an error (string message, optional underlying exception)
errors.add("Something went wrong")
errors.add("Sync failed", exception)

# Add an informational notice
notices.add("Processing started")

# Inspect state
service.success?            # => true when there are no errors
service.errors?             # => true when there is at least one error
service.errors.any?         # => same idea, on the collection
service.errors.full_messages # => "First error\nSecond error" (newline-joined)
service.notices.full_messages

# The resolved single message — errors win; otherwise notices; otherwise the success_notice
service.notice              # alias: service.message

# Suggested Rails flash key for the current state
service.flash_key           # => :alert when errored, :notice when clean
```

`notice` resolution order:

1. If there are errors → the joined error messages.
2. Else if there are notices → the joined notice messages.
3. Else → the declared `success_notice` (or a generated `"<ServiceName> succeeded"` fallback).

### Steroids vs ActiveRecord Errors

The collection is **string-first**. There is no attribute/symbol key.

```ruby
# ✅ CORRECT — Steroids
errors.add("Email is required")
errors.add("Upstream timed out", exception)

# ❌ WRONG — ActiveRecord style. Raises (the message must be a String).
errors.add(:base, "Email is required")
errors.add(:email, "is required")
```

<a name="noticable-dos-and-donts"></a>
### Dos and Don'ts

✅ **Do** pass full, human-readable sentences to `errors.add` — they may surface directly in a flash or API payload.

✅ **Do** pass the originating exception as the second argument; it's used for logging and observability.

❌ **Don't** pass a symbol as the first argument. The message must be a `String`.

❌ **Don't** build your own success-vs-error branching with ad-hoc booleans — use `success?` / `errors?` / `flash_key`.

---

## Controller Integration

Include the controller concern, then declare services declaratively with the `service` macro.

```ruby
class ApplicationController < ActionController::Base
  include Steroids::Controllers::Methods
end
```

### The `service` Macro

```ruby
class UsersController < ApplicationController
  service :create_user, class_name: "Users::CreateService"
  service :update_user, class_name: "Users::UpdateService"
  service :sync_avatar, class_name: "Users::SyncAvatarService", async: true

  def create
    create_user(user_params) do |service|
      if service.success?
        redirect_to users_path, notice: service.notice
      else
        flash.now[:alert] = service.errors.full_messages
        render :new
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
```

`service :name, class_name:, async: false` defines an instance method `name(...)` that:

- resolves and instantiates the service class,
- forwards your arguments into `initialize`,
- runs it inline (`async: false`, the default) or enqueues it (`async: true`),
- yields the service to your block.

### Block Form & `flash_key`

The block works identically in sync and async mode. Declaring a `flash_key:` parameter lets you write the redirect once, regardless of outcome:

```ruby
def sync
  sync_avatar(user_id: params[:id]) do |service, flash_key:|
    redirect_to user_path(params[:id]), flash_key => service.notice
  end
end
```

`flash_key` is `:notice` on success and `:alert` on failure — so the same line renders a success or error flash correctly.

> In **async** mode the block fires immediately after the job is enqueued, with a
> fresh preview instance carrying only the class-declared `success_notice`. The
> actual work runs later in the worker; worker-side errors do not surface to the
> request.

### Direct Calls

You don't have to use the macro. Call the service directly when you need full control over the response:

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

> Heads up: a block-less `.call` **raises** on failure (see
> [Return Values & Error Propagation](#return-values--error-propagation)). The
> snippet above works because `CompleteOrderService` defines `rescue!`, which
> captures the failure into `errors` instead of raising. If your service has no
> `rescue!`, prefer the block form.

### `respond_with` & Serializers

`Steroids::Controllers::Methods` also ships a JSON-oriented `respond_with` and a default serializer hook:

```ruby
class Api::PostsController < ApplicationController
  default_serializer PostSerializer

  def index
    respond_with Post.all, paginate: true
  end

  def show
    respond_with Post.find(params[:id])
  end
end
```

`respond_with` applies the controller's default serializer, optional scopes, and pagination for `ActiveRecord::Relation`s, and falls back to `head`/`NotFoundError` when there's nothing to render.

<a name="controller-dos-and-donts"></a>
### Dos and Don'ts

✅ **Do** declare services with the macro and keep controller actions to a single block.

✅ **Do** use `service.notice` and `service.flash_key` instead of hardcoding messages.

❌ **Don't** mark request-blocking work `async: true` and then read its result in the block — async blocks only see the declared `success_notice`, not the outcome.

❌ **Don't** forget `include Steroids::Controllers::Methods` — without it the `service` macro and `respond_with` are undefined.

---

## Async Dispatch

Async-ness is a **caller** decision, not a property of the service. Every service defines one `process`; the caller picks `.call` (inline) or `.call_async` (enqueue `Steroids::AsyncServiceJob`).

```ruby
class SendNewsletterService < Steroids::Services::Base
  success_notice "Newsletter sent to all subscribers"

  def initialize(subject:, body:)
    @subject = subject
    @body    = body
  end

  def process
    User.subscribed.find_each do |user|
      NewsletterMailer.weekly(user, @subject, @body).deliver_now
    end
  rescue StandardError => e
    errors.add("Newsletter delivery failed", e)
  end
end
```

### `call` vs `call_async`

```ruby
# Inline — blocks the caller until `process` returns.
SendNewsletterService.call(subject: "Hi", body: "...")
SendNewsletterService.call_sync(subject: "Hi", body: "...")  # explicit alias

# Background — enqueues Steroids::AsyncServiceJob, returns the job handle.
SendNewsletterService.call_async(subject: "Hi", body: "...")
```

There is **no auto-detection**: `.call` never enqueues, `.call_async` never runs inline. This is deliberate — earlier heuristics that picked a mode automatically produced silent race conditions when the same service was invoked from both paths. Explicit dispatch removes that class of bug.

> `call_async` accepts **keyword arguments only** — positional args can't be
> serialized reliably for the worker.

### Background-only Services (`async_only!`)

For work that must never block the request thread, mark the class:

```ruby
class ImportLargeCatalogService < Steroids::Services::Base
  async_only!   # `.call` / `.call_sync` raise AsyncOnlyError; only `.call_async` works

  def process
    # heavy, multi-minute import
  end
end
```

### Per-mode Success Notices

`success_notice` accepts either a **String** (one message for both modes) or a **Hash** keyed by `:sync` / `:async`, so the same service renders an accurate flash either way:

```ruby
class SendNewsletterService < Steroids::Services::Base
  # Explicit per-mode messages
  success_notice sync:  "Newsletter sent to all subscribers",
                 async: "Newsletter queued — subscribers notified shortly"
end

class FlagAccountService < Steroids::Services::Base
  # String form — in async dispatch the resolver appends " (async)" so the
  # message stays accurate ("Account flagged (async)") without claiming the
  # work has already completed.
  success_notice "Account flagged"
end
```

Resolution rules:

| `success_notice` declaration | sync mode | async mode |
|---|---|---|
| `"<string>"` | `"<string>"` | `"<string> (async)"` |
| `sync: "S", async: "A"` | `"S"` | `"A"` |
| `async: "A"` (no sync key) | `"<ClassName> succeeded"` | `"A"` |
| `sync: "S"` (no async key) | `"S"` | `"Queued for background processing."` |
| (not declared) | `"<ClassName> succeeded"` | `"Queued for background processing."` |

In a `service :name, ..., async: true` controller helper, the preview instance the block receives already has `dispatch_mode = :async`, so `service.notice` reads the right message with no extra wiring.

### Serializability Validation

`.call_async` walks the init args **before** enqueuing. If anything can't be serialized for ActiveJob (Procs, IO, anonymous classes, unpersisted records…), it raises `Steroids::Services::Base::NonSerializableArgumentError` with a dotted-path list of every offender — no more silent worker-side `SerializationError`.

```ruby
# ✅ Serializable — primitives, Symbols, Date/Time, persisted AR records, GlobalID-aware objects
SendNewsletterService.call_async(subject_id: 42, recipient: persisted_user)

# ❌ Raises NonSerializableArgumentError, listing each bad arg:
SendNewsletterService.call_async(after: ->(u) { ... }, sink: $stdout)
#   - after (Proc)
#   - sink (IO)
```

### Control Flags

`force:` and `skip_callbacks:` are accepted alongside init args on both entry points. They control the run (they are *not* forwarded into `initialize`). In async mode they ride along to the worker via the job's `control:` argument.

```ruby
MyService.call(value: 1, skip_callbacks: true)
MyService.call_async(value: 1, force: true)   # the worker honors it
```

---

## Steroids Errors

Steroids ships an HTTP-aware error hierarchy rooted at `Steroids::Errors::Base`. These errors carry a status, a code, a context hash, an id, a timestamp, and optionally a cause — and they serialize cleanly to JSON.

### The Base Error

```ruby
class PaymentDeclinedError < Steroids::Errors::Base
  self.default_message = "The payment was declined"
  self.default_status  = :payment_required
end

raise PaymentDeclinedError.new("Card expired")

raise PaymentDeclinedError.new(
  message: "Card expired",
  status:  :payment_required,
  code:    "CARD_EXPIRED",
  cause:   original_exception,
  context: { account_id: account.id },
  log:     true            # log immediately on construction
)
```

Every instance exposes:

```ruby
begin
  # ...
rescue Steroids::Errors::Base => e
  e.message    # resolved message (falls back to default_message)
  e.status     # HTTP status symbol, e.g. :payment_required
  e.code       # numeric/string code (defaults to the HTTP status code)
  e.cause      # the wrapped exception, if any
  e.errors     # collected sub-errors (e.g. AR validation messages)
  e.context    # the context hash you passed
  e.id         # a UUID for cross-referencing logs
  e.timestamp  # when the error was constructed
end
```

When you pass a `cause`, Steroids derives the status and validation errors from it automatically (including `ActiveRecord` rescue-response mappings and record validation messages).

### HTTP Error Classes

Ready-made subclasses, each with a sensible default status:

| Class | Status |
|---|---|
| `Steroids::Errors::BadRequestError` | `:bad_request` (400) |
| `Steroids::Errors::UnauthorizedError` | `:unauthorized` (401) |
| `Steroids::Errors::ForbiddenError` | `:forbidden` (403) |
| `Steroids::Errors::NotFoundError` | `:not_found` (404) |
| `Steroids::Errors::ConflictError` | `:conflict` (409) |
| `Steroids::Errors::UnprocessableEntityError` | `:unprocessable_content` (422) |
| `Steroids::Errors::InternalServerError` | `:internal_server_error` (500) |
| `Steroids::Errors::NotImplementedError` | `:not_implemented` (501) |
| `Steroids::Errors::GenericError` | `:generic_error` |

```ruby
raise Steroids::Errors::NotFoundError.new("No such invoice")
raise Steroids::Errors::ForbiddenError.new("Admins only")
raise Steroids::Errors::UnprocessableEntityError.new("Validation failed")
```

### Serializing Errors for APIs

Errors render to a structured JSON payload (id, code, status, message, quote, errors, timestamp — plus the exception class in development). Wire them up once with `rescue_from`:

```ruby
class Api::BaseController < ActionController::API
  rescue_from Steroids::Errors::Base do |error|
    render json: error.to_json, status: error.status
  end
end
```

### Observability Seam

Handled exceptions inside a service are forwarded through `Steroids::ErrorReporter`, an agnostic seam that delegates to Rails' unified `Rails.error.report`. Whatever your app subscribes there (Sentry, Honeybadger, AppSignal, …) receives the report — Steroids stays tool-agnostic and degrades to a no-op outside Rails.

Reporting is **idempotent** (each exception is reported at most once, even if re-raised up the stack). Mark an error class as "expected" to keep it out of your dashboards:

```ruby
class UserFacingValidationError < Steroids::Errors::Base
  self.report_to_observability = false   # flow-control error; not an incident
end
```

<a name="error-dos-and-donts"></a>
### Dos and Don'ts

✅ **Do** subclass `Steroids::Errors::Base` for domain errors and set `default_message` / `default_status`.

✅ **Do** pass `context:` with the ids and params relevant to the failure — it travels into your logs and observability tool.

✅ **Do** set `report_to_observability = false` on expected, user-facing errors to keep dashboards focused on real incidents.

❌ **Don't** `raise SomeError.new(message: "...")` and *also* re-implement status/JSON yourself — `to_json` and `status` already do it.

❌ **Don't** swallow a `cause` — pass it through so the backtrace and validation errors survive.

---

## Logger

`Steroids::Logger` is a colorized, backtrace-aware logger that also detects exception severity and can notify an external service.

```ruby
# Plain messages
Steroids::Logger.print("Operation completed")

# Exceptions — level, color, and backtrace are inferred automatically
begin
  risky_operation
rescue => e
  Steroids::Logger.print(e)
end
```

**Verbosity** controls the backtrace:

```ruby
Steroids::Logger.print(exception, verbosity: :full)    # full backtrace (default for exceptions)
Steroids::Logger.print(exception, verbosity: :concise) # just the originating app frame
Steroids::Logger.print(exception, verbosity: :none)    # no backtrace
```

**Format** controls decoration:

```ruby
Steroids::Logger.print("Message", format: :decorated)  # colored, labeled (default)
Steroids::Logger.print("Message", format: :raw)        # plain
```

**Automatic levels:**

- `:error` — `StandardError`, `InternalServerError`, `GenericError`
- `:warn` — other `Steroids::Errors::Base` subclasses
- `:info` — plain messages

**Notifications** — register a callable to be invoked for `:error` / `:warn` exceptions:

```ruby
# config/initializers/steroids.rb
Steroids::Logger.notifier = lambda do |exception|
  Sentry.capture_exception(exception)
end
```

Colors (via [Rainbow](https://github.com/sickill/rainbow)): 🔴 red = errors, 🟡 yellow = warnings, 🟢 green = info, 🟣 magenta = class names / quiet logs.

---

## Extensions

Steroids adds a small, pragmatic set of methods to Ruby core classes. They load automatically.

### Object Extensions

```ruby
# Runtime type assertions
name.typed!(String)        # returns name, or raises TypeError if not a String
name.typed(String)         # returns name if it matches (or is nil), else nil

# Nil-coalescing
config.timeout.ifnil(30)   # => config.timeout, or 30 when nil

# Boolean check
flag.boolean?              # => true only for literal true/false

# Safe dispatch — calls the method only if it exists, adapting arity; else nil
object.send_apply(:optional_hook, arg)

# Grab a Method object if the method exists (including private), else nil
m = object.try_method(:process)

# Serialization helpers
payload.serializable?      # => true if the whole structure is JSON-serializable
data.deep_serialize        # recursively serialize nested hashes/arrays
object.marshallable?       # => true if Marshal.dump succeeds
```

### Array Extensions

```ruby
# Assert a value is a member of an allow-list (raises ElementNotFound otherwise)
STATES = %i[draft published archived]
STATES.cast(:published)        # => :published
STATES.cast(:bogus)            # raises Steroids::Extensions::ArrayExtension::ElementNotFound

# Indifferent (symbol/string) matching
STATES.cast("published", true) # => :published

# Map-and-find — returns the first truthy block result
users.find_map { |u| u.admin? && u.email }
```

### Hash Extensions

```ruby
# Return the value for the first key that exists
params.fetch_any(:user_id, :id)   # => params[:user_id] || params[:id]
```

### Class, Method & Module Extensions

For framework-style code, Steroids also provides:

- `Class#attribute(name, default:, type:, allow_nil:)` — typed, defaulted instance attributes.
- `Class#delegate_alias(name, to:, method:)` and `Class#try_delegate(*names, to:)` — flexible delegation.
- `Method#apply` / `Proc#apply` — call a method or proc while **adapting the arguments to its arity** (this is what lets service blocks declare `|service|`, `|service, outcome|`, or `|service, flash_key:|` interchangeably).
- `Module#create_namespace("A::B::C")` — idempotently define nested module namespaces.

<a name="extension-dos-and-donts"></a>
### Dos and Don'ts

✅ **Do** use `typed!` at trust boundaries (public method inputs) to fail fast with a clear `TypeError`.

✅ **Do** use `send_apply` for optional hooks where the method may not be defined.

❌ **Don't** use `cast` for control flow where a miss is expected — it *raises*. Use `include?` for a boolean check.

❌ **Don't** reach for `deep_serialize` on objects with cycles — it walks the structure eagerly.

---

## Types

`Steroids::Types::Base` provides a lightweight, validatable value object built on `ActiveModel`. Declare attributes, mark some required, and validate:

```ruby
class AddressType < Steroids::Types::Base
  attribute :street
  attribute :city
  attribute :country

  requires :street
  requires :country
end

address = AddressType.new(street: "1 Main St", country: "US")
address.validate!   # raises InternalServerError listing missing required attributes
address.values      # => { street: "1 Main St", city: nil, country: "US" }
```

---

## Serializers (Deprecated)

> ⚠️ **Deprecation:** the Serializers module is a thin wrapper around
> `ActiveModel::Serializer` and will be removed in a future major version.
> Prefer [ActiveModel::Serializer](https://github.com/rails-api/active_model_serializers)
> or [Blueprinter](https://github.com/procore/blueprinter) directly in new code.

```ruby
class UserSerializer < Steroids::Serializers::Base
  attributes :id, :name, :email
  has_many :posts
end

UserSerializer.new(user).to_json
```

---

## Testing

Steroids' own suite uses **RSpec**. Services are easy to test because they are plain objects with a single entry point.

```ruby
RSpec.describe CreateUserService do
  describe ".call" do
    context "with valid params" do
      subject { described_class.call(name: "Ada", email: "ada@example.com") }

      it { is_expected.to be_a(User) }

      it "creates a user" do
        expect { subject }.to change(User, :count).by(1)
      end
    end

    context "with invalid params" do
      it "surfaces errors via the block form" do
        described_class.call(name: "") do |service|
          expect(service).to be_errors
          expect(service.errors.full_messages).to match(/failed/i)
        end
      end

      it "raises when called without a block" do
        expect { described_class.call(name: "") }
          .to raise_error(Steroids::Support::NoticableMethods::RuntimeException)
      end
    end
  end
end
```

Testing async dispatch:

```ruby
RSpec.describe SendNewsletterService do
  it "enqueues the async job" do
    expect { described_class.call_async(subject: "Hi", body: "...") }
      .to have_enqueued_job(Steroids::AsyncServiceJob)
  end

  it "runs inline with .call" do
    result = described_class.call(subject: "Hi", body: "...")
    expect(result).to be_truthy
  end
end
```

Run the suite:

```bash
$ bundle exec rspec                       # everything
$ bundle exec rspec spec/services         # a directory
$ bundle exec rspec spec/services/base_spec.rb:42  # a single example
```

---

## Configuration

Most behavior is per-service or per-call. The knobs:

```ruby
# Per-class: opt out of the automatic transaction wrap
class SyncPriceService < Steroids::Services::Base
  wrap_in_transaction false
end

# Per-class: forbid synchronous execution
class ImportService < Steroids::Services::Base
  async_only!
end

# Per-call: skip callbacks / disable drop!
MyService.call(data: data, skip_callbacks: true)
MyService.call(data: data, force: true)

# Global: error notifier (an initializer)
Steroids::Logger.notifier = ->(exception) { Sentry.capture_exception(exception) }
```

---

## Development

### Local Development

When developing Steroids alongside a host application, use Bundler's local gem override:

```bash
$ bundle config set local.steroids /path/to/local/git/repository
$ bundle config set disable_local_branch_check true
$ bundle install
```

Your app now uses your working copy; changes are picked up on Rails reload. To remove the override:

```bash
$ bundle config --delete local.steroids
$ bundle install
```

### Running Tests

```bash
$ bundle exec rspec
```

---

## Troubleshooting

**`TypeError: Expected … to be an instance of String`** — you passed a symbol to `errors.add`. Use a string message: `errors.add("Email is required")`, not `errors.add(:email, "...")`.

**A block-less `.call` raised unexpectedly** — that's by design. Without a block, a failed service raises `Steroids::Support::NoticableMethods::RuntimeException`. Pass a block (or define `rescue!`) to capture errors instead.

**`AsyncOnlyError` when calling a service** — the class is marked `async_only!`. Use `.call_async`.

**`NonSerializableArgumentError` from `.call_async`** — one of your init args can't be serialized for ActiveJob (a Proc, IO, unpersisted record…). The message lists each offender; pass only primitives, Symbols, Date/Time, persisted records, or GlobalID-aware objects.

**Async service never runs** — make sure an ActiveJob backend is running and processing the `:default` queue.

**Transaction didn't roll back** — confirm the service hasn't opted out via `wrap_in_transaction false`, and that the failure raised or called `drop!` (merely adding to `errors` after `process` returns also rolls back, but only via the automatic post-process drop).

---

## Roadmap

- [ ] Standalone testing with a bundled dummy Rails app
- [ ] Generator for service objects
- [ ] Built-in metrics & instrumentation
- [ ] Service composition primitives
- [ ] Streaming / progress notices for long-running async services

---

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/wandernb/steroids>.

## Disclaimer

This gem is under active development and may not strictly follow SemVer. Pin a version in production.

## Credits

Created and maintained by Paul R.

## License

Available as open source under the terms of the [MIT License](LICENSE.md).
