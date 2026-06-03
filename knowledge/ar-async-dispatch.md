# ar-async-dispatch — Per-call async dispatch model

Source: `lib/steroids/services/base.rb` (class methods), `app/jobs/steroids/async_service_job.rb`, `lib/steroids/support/servicable_methods.rb`.

## Design principle

**Async-ness is a caller decision, not a service property.** Every `Services::Base` subclass defines exactly one `def process`. The caller picks one of:

| Entry point | Behavior | Raises on … |
|-------------|----------|-------------|
| `.call(*, **)` | Run `process` inline | `async_only!` services |
| `.call_sync(*, **)` | Alias for `.call` (more readable at call sites) | `async_only!` services |
| `.call_async(**)` | Enqueue `Steroids::AsyncServiceJob` | positional args; non-serializable init args |

This replaces an older `async_process` method + `Sidekiq.server?` auto-detection heuristic that produced silent race conditions when a service was invoked from both sync and async paths. See [[wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite]] for the rewrite history and the prior `@2026-05-11-01` wrapup for the observability batch that preceded it.

## Argument splitting

Class methods `.call` and `.call_async` route keyword args through `split_options`:
- `CONTROL_OPTIONS = %i[force skip_callbacks].freeze` → **control** (forwarded to `#call(**ctrl)` or `AsyncServiceJob`'s `control:`).
- Everything else → **init** (passed to `new(**init)`).

`.call_async` additionally **forbids positional args** (`ArgumentError`), because ActiveJob would have nothing to serialize them as in a stable way.

## Serializability validation (eager, call-site)

```ruby
PRIMITIVE_SERIALIZABLE = [
  String, Symbol, Numeric, TrueClass, FalseClass, NilClass,
  Date, Time, DateTime
].freeze
```

`validate_serializable!` walks the init opts via `collect_unserializable`:

- Recurses into Hashes (tracking dotted paths like `"user.profile.handler"`).
- Recurses into Arrays (with `[N]` index path segments).
- `BigDecimal` and persisted `ActiveRecord::Base` records are OK; unpersisted records are flagged.
- Anything responding to `:to_global_id` is OK (GlobalID-aware objects).
- Anything else → flagged.

When offenders are found, raises `Steroids::Services::Base::NonSerializableArgumentError` with **every** offender + class + dotted path in a single message. This fails fast at the call site instead of inside the worker (where ActiveJob would raise an opaque `SerializationError`).

## The job

```ruby
class Steroids::AsyncServiceJob < ActiveJob::Base
  queue_as :default

  def perform(class_name:, params:, control: {})
    service_class = class_name.constantize
    instance = service_class.new(**params.symbolize_keys)
    control = (control || {}).symbolize_keys
    instance.instance_variable_set(:@steroids_force, !!control[:force])
    instance.instance_variable_set(:@steroids_skip_callbacks, !!control[:skip_callbacks])
    instance.send(:exec_process)
  end
end
```

- `params` is whatever `init_opts.deep_serialize` produced at enqueue time (so it's plain Hash/Array/primitive).
- `control` carries the same `force:` / `skip_callbacks:` flags accepted by inline `.call`.
- The worker invokes `exec_process` directly (skipping the public `#call`) — there's no caller block to apply, and the noticable layer captures errors the same way it does inline.

## `async_only!`

```ruby
class HeavyService < Steroids::Services::Base
  async_only!
  def process; long_running_work; end
end

HeavyService.call         # → raises AsyncOnlyError
HeavyService.call_sync    # → raises AsyncOnlyError
HeavyService.call_async   # OK
```

`AsyncOnlyError < Steroids::Errors::Base` with a `default_message` pointing the developer at `.call_async`.

## Controller integration

```ruby
service :sync_price,    class_name: "SyncPriceService"                  # sync
service :sync_bundles,  class_name: "SyncBundlesService", async: true   # enqueue
```

For `async: true` (in `support/servicable_methods.rb`):

1. `service_class.call_async(*args, **merged_options)` returns the enqueued job.
2. If the controller passed a block, a **preview instance** is built (`service_class.new(*args, **merged_options)`).
3. The preview's `noticable.dispatch_mode` is flipped to `:async`.
4. The block is invoked via `Method#apply` with `(preview, job, noticable:, flash_key:)`.

This is what makes `redirect_to path, service.flash_key => service.notice` work identically for sync vs async — the controller doesn't care, the macro hands it the right `notice` value either way.

**Worker-side errors do not surface to the request.** If the background job fails, the controller has already responded. Use [[ar-errors-observability]] (the `ErrorReporter` seam) to report those failures to your APM.

## Test coverage

`spec/steroids/services/async_dispatch_spec.rb` (plus `spec/steroids/services/option_split_spec.rb` and `spec/steroids/support/servicable_async_spec.rb`; RSpec since the 2026-06-03 migration) covers:
- `.call` runs inline / doesn't enqueue
- `.call_sync` alias
- `.call_async` enqueues with the correct payload
- `control:` flags forwarded to the worker
- Positional args refused
- `NonSerializableArgumentError` lists each offender (Procs, IO, unpersisted records, anonymous classes) with dotted paths
- Primitives + persisted AR records + GlobalID objects accepted
- `async_only!` enforcement on all three entry points
- Per-mode notice resolution (4 scenarios — see table in [[ar-noticable]])
- Worker round-trip via `perform_now`

Suite uses ActiveJob's `:test` adapter.

## Migration notes (from the old model)

The removed surface:
- `async_process` method (separate from `process`) — **gone**.
- `async?` / `validate_process_definition!` / `AmbiguousProcessMethodError` / `AsyncProcessArgumentError` — **gone**.
- The new-time `@_steroids_serialized_init_options` capture — **gone**.
- `schedule_process` and `async_exec?` (with the `Sidekiq.server?` heuristic) — **gone**.

If you find references to any of these in a host app, they need to migrate to `.call_async` at the call site. See `CHANGELOG.md` `[Unreleased]` for the breaking-change writeup and [[wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite]] for the full diff inventory.
