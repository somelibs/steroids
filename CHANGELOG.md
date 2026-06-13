# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — per-class transaction opt-out
- **`Steroids::Services::Base.wrap_in_transaction(false)`** — class macro that opts a single service out of the automatic `ActiveRecord::Base.transaction` wrap (backed by a new `wrap_in_transaction_override` `class_attribute`). Use it for services that primarily hit a third-party API so a slow network round-trip doesn't hold a pooled DB connection open or extend the transaction boundary across remote latency. When unset (`nil`), the wrap defaults to on. Resolves the long-standing "should the transaction wrap be per-service?" backlog item.

### Removed — `@@wrap_in_transaction` shared class variable
- **Removed the `@@wrap_in_transaction` class variable** that backed the transaction-wrap default. It was a footgun: assigning `@@wrap_in_transaction = false` inside a subclass writes the *ancestor's* class variable, so one service opting out silently disabled the transaction wrap for every sibling service in the host app. The default now lives in `wrap_in_transaction?` (`override.nil? || override`) with the per-class `wrap_in_transaction_override` `class_attribute` as the only switch — `class_attribute` inherits without leaking. A regression test asserts a stray `@@wrap_in_transaction` assignment is inert.

### Changed — test framework
- **Migrated the test suite from Minitest to RSpec.** Specs now live under `spec/` (mirroring `lib/`), 220 examples / 0 failures. Adds `rspec` (~> 3.13), `rspec-rails` (~> 7.1), and `simplecov` (~> 0.22) as development-group gems; the old `test/` Minitest suite and `bundle exec rake test` runner are replaced by `bundle exec rspec`. The six pre-existing service-call-contract errors tracked in earlier (Minitest-era) notes are gone — the migration settled the call contract they hinged on (block-less `.call` raises on failure; the block form captures).

### Documentation
- **Rewrote `README.md`** as a single comprehensive, consolidated API tour (services, noticable, controller integration, async dispatch, error hierarchy, logger, extensions, types) with per-section "dos and don'ts". Corrected stale claims from the prior revision: Ruby ≥ 3.3 / Rails ≥ 7 (was 3.0 / 7.1), RSpec (was Minitest), the real `wrap_in_transaction false` macro (was a non-existent `self.wrap_in_transaction =` setter), block-less `.call` **raises** on failure (was "returns nil"), and removed the non-existent `async:` control flag.

### Fixed
- **`Steroids::Extensions::MethodExtension#apply`** — switched from `self.yield(...)` to `self.call(...)`. `Method` has no `yield`; the method only worked on Procs (since `Proc#yield` is an alias for `Proc#call`). Now works on both, matching the docstring intent and unblocking `method.apply` for any consumer.
- **`Steroids::Logger#print`** — the `notify(level, ...)` call now receives the original `@exception` (or `@input`), not the formatted output string. `notify` filters on `input.is_a?(Exception)`, so passing the formatted String meant the notifier callback **never fired** for exceptions. Now `Steroids::Logger.notifier = proc { |exc| ... }` correctly invokes for `:error` / `:warn` level exceptions.
- **`Steroids::Logger#notify`** — reads the notifier via `self.class.notifier` so the class-level `Steroids::Logger.notifier =` setter is honored from the instance method (previously it read the instance ivar `@notifier`, which is never set).
- **`Steroids::Logger#format_backtrace`** — guards `@backtrace.any?` with safe navigation. Previously raised `NoMethodError: undefined method 'any?' for nil` when logging an exception that was instantiated but never raised (so its `.backtrace` is `nil`).

### Added — tooling
- **`.rubocop.yml`** with a project-tailored config (Ruby 3.3+, Rails 7+). `.rubocop_todo.yml` baselines existing offenses so `bundle exec rubocop` is green on the existing codebase; new code is held to the configured standard. Adds `rubocop`/`rubocop-rails` as development-group gems.

### Added — test coverage
- **`test/extensions/`** — new tests for `object_extension`, `array_extension`, `hash_extension`, `method_extension`, `class_extension`, `module_extension`. ~50 new tests / ~95 assertions covering `typed!`, `send_apply`/`send_apply!`, `instance_apply`, `serializable?`/`deep_serialize`, `Array#cast`/`#find_map`, `Hash#fetch_any`, `Method#apply` arity matching across kw/positional/rest, `Class#attribute` typed reader/writer, `Class#delegate_alias`, `Class#build_anonymous`, `Module#create_namespace`.
- **`test/logger_test.rb`** — new tests exercising level inference (info / warn / error), the notifier callback, and the "already logged" short-circuit.
- **`test/types/`** — new tests for `Steroids::Types::SerializableType` (attribute tracking, mass assignment) and `Steroids::Types::Base` (required-attribute enforcement, `ignore_required`, `.import` exception wrapping).

### Changed — test cleanup
- **`test/services/async_service_test.rb`** — replaced the `singleton_class.alias_method` trampoline in the worker round-trip test with a dedicated `ConstructorSpyService` fixture; replaced the `CallbackService.class_eval { define_method(:setup) }` swap in the `skip_callbacks` test with a dedicated `CallbackCounterService` fixture. Both tests now read straight-through without relying on test-order isolation.
- **`test/errors/error_serializer_test.rb`** — wrapped the `Rails.define_singleton_method(:env)` stub in `silence_warnings` so the "method redefined" output no longer appears in test runs.

### Changed (BREAKING) — per-call async dispatch
- **Async-ness is now a caller decision, not a service property.** Services define a single `def process`; callers pick `.call` (inline) or `.call_async` (enqueue). The two entry points sit side-by-side on every service.
- `def async_process` is **removed**. Migration: rename to `def process`. Callers that previously got auto-enqueue out-of-Sidekiq must switch to `.call_async`; callers that previously forced inline via `.call(async: false)` just drop the kwarg and call `.call`.
- `.call(async: …)` keyword arg is **removed**. Use `.call_async` / `.call_sync` instead.
- The `!Sidekiq.server?` auto-detection heuristic in `schedule_process` is **removed**. `.call` now always runs inline; `.call_async` always enqueues. This eliminates the silent race where a service called sync in one path was auto-enqueued in another and the work happened later than the caller expected.
- `class.async?`, `validate_process_definition!`, `AmbiguousProcessMethodError`, `AsyncProcessArgumentError`, and the new-time `@_steroids_serialized_init_options` serialization are all **removed** — none are reachable in the new model.
- `async_only!` is **kept**. On a class marked `async_only!`, `.call` / `.call_sync` raise `Steroids::Services::Base::AsyncOnlyError` with a clear message pointing at `.call_async`.
- The `service :name, class_name:, async: true` macro option now **enqueues** via `.call_async`. The block form works in both sync and async mode; in async mode the block fires immediately after enqueue with a fresh service instance carrying only the class-declared `success_notice` (worker-side errors do not surface to the request).
- `Steroids::AsyncServiceJob.perform` signature gained an optional `control:` kwarg (default `{}`) carrying `force:` / `skip_callbacks:` from `.call_async` through to the worker.

### Added — call-site serializability validation
- `Steroids::Services::Base::NonSerializableArgumentError` — raised by `.call_async` before any enqueue when init args contain values ActiveJob cannot round-trip (Procs, IO, anonymous classes, unpersisted records, …). The message lists every offender with a dotted path + class name, e.g. `value.config.handler (Proc)` — no more silent worker-side `SerializationError`.
- `Steroids::Services::Base.call_sync` — explicit alias of `.call`, useful at call sites where the symmetry with `.call_async` reads better.

### Added — per-mode success notices
- `success_notice` now accepts a Hash keyed by `:sync` / `:async` in addition to a plain String, so the same service can render an accurate flash in either dispatch mode:
  ```ruby
  success_notice sync:  "Newsletter sent to all subscribers",
                 async: "Newsletter queued — subscribers notified shortly"
  ```
  Resolution rules: plain String — sync as-is, async appends `" (async)"` so the message stays accurate without claiming completion. Hash — the key matching the current dispatch mode is used; missing keys fall back to `"Queued for background processing."` (async) or the `"<ClassName> succeeded"` placeholder (sync).
- `Steroids::Support::NoticableMethods::NoticableRuntime#dispatch_mode` — new accessor (default `:sync`); the `service :name, ..., async: true` macro flips it to `:async` on the preview instance the block yields, so `service.notice` reads the right message automatically.

### Added — observability
- `Steroids::ErrorReporter` — agnostic seam that forwards *handled* exceptions through `Rails.error.report` (and on to whatever observability subscriber the parent app registered). Idempotent per exception, no-ops when `Rails.error` is unavailable, and never raises.
- `Steroids::Services::Base#report_error!` (alias `report_to_observability!`) — called automatically for every rescued `StandardError` in a service; subclasses can also call it from their own rescue blocks. Accepts context tags forwarded to the reporter.
- `Steroids::Errors::Base.report_to_observability` class attribute (default `true`) — set to `false` on "expected" error subclasses (validation, flow control) to keep them out of observability dashboards.
- `Steroids::Support::NoticableMethods` — `flash_key` (`:alert` when there are errors, otherwise `:notice`), also delegated to the includer and passed to service block callbacks as `flash_key:`.

### Changed
- `Steroids::ErrorSerializer` — the `exception` attribute is still dev-only; the redundant duplicate `message` declaration in the dev-only block was removed (`message` is already serialized unconditionally).

### Fixed
- Unregistered `Steroids::Errors::Base` subclasses now fall back to their own `default_status` instead of always resolving to `:internal_server_error`. `ActionDispatch::ExceptionWrapper.rescue_responses` is a Hash with a default value, which previously short-circuited the status resolution for any error class the consuming app had not manually registered.
- README: `bundle config local.steroids …` / `bundle config disable_local_branch_check …` updated to the `bundle config set …` form.
