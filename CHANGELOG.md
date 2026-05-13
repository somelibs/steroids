# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
