# ar-overview — Architecture & code organization

Steroids is a Rails **Engine + Railtie**. It hooks into a host app via Zeitwerk autoload (set up on require) and a `to_prepare` reloader that watches the gem's own files in dev mode.

## Boot sequence

1. `require "steroids"` → `lib/steroids.rb` requires `steroids/railtie` and `steroids/engine`, then:
   - `Steroids.loader.zeitwerk.setup` — registers a Zeitwerk loader tagged `"steroids"`, pushed at `lib/steroids` with `GemInflector`.
   - `Steroids.loader.load_extensions!` — explicit `require` of every `lib/steroids/extensions/**/*.rb` so Ruby core classes are monkey-patched at load time, before any host code runs.
2. `Steroids::Engine` (`< Rails::Engine`) — exposes `config.steroids = Steroids`. Nothing else.
3. `Steroids::Railtie`:
   - `config.to_prepare` — if the file-update checker fires, `zeitwerk.reload` is called.
   - `initializer "steroids.add_reloader"` — registers the file-update checker with the host app so reload triggers `load_extensions!` again.

The custom `Steroids::Loader` (defined in `engine.rb`) wraps both Zeitwerk and an `ActiveSupport::FileUpdateChecker` over `Dir["#{gem_path}/**/*.rb"]`.

## Directory layout

```
lib/
  steroids.rb                       # entry point
  steroids/
    engine.rb                       # Loader + Engine + Railtie
    railtie.rb                      # (re-exports — historical split)
    version.rb                      # VERSION constant
    logger.rb                       # Steroids::Logger (rainbow formatter)
    error_reporter.rb               # agnostic observability seam
    errors.rb                       # HTTP error subclasses
    errors/
      base.rb                       # Steroids::Errors::Base
      context.rb                    # HTTP status mapping concern
      quotes.rb                     # cached random-quote concern
    services/
      base.rb                       # Steroids::Services::Base
    support/
      magic_class.rb                # superclass for Services::Base + Types
      noticable_methods.rb          # errors/notices + dispatch_mode resolver
      servicable_methods.rb         # `service` macro for controllers
    extensions/                     # ruby core monkey-patches (object/hash/array/method/proc/class/module)
    types/
      serializable_type.rb          # ActiveModel::Model attributes
      base.rb                       # + requires/validate_required!/import
    serializers/
      base.rb                       # < ActiveModel::Serializer
      methods.rb                    # nil-pruning + param coercion
    controllers/
      methods.rb                    # composite concern
      responders_helper.rb          # respond_with JSON renderer
      serializers_helper.rb         # default_serializer class macro

app/
  jobs/steroids/async_service_job.rb     # ActiveJob worker
  serializers/steroids/error_serializer.rb
```

## Key inheritance chains

```
Steroids::Services::Base
  < Steroids::Support::MagicClass        # includes NoticableMethods
    include Support::ServicableMethods   # service() class macro (also pulled into controllers)
    include Support::NoticableMethods    # errors/notices/notice/flash_key

Steroids::Types::Base
  < Steroids::Types::SerializableType
    < Steroids::Support::MagicClass
      include ActiveModel::Model + Serialization

Steroids::Errors::Base
  < StandardError
    include ActiveModel::Serialization, Context, Quotes
```

## Hot paths

- **Service call (sync)** → `Steroids::Services::Base.call` → `split_options` → `new(**init)` → `#call(**ctrl)` → `exec_process` → `process_wrapper` (transaction) → `run_before_callbacks` → `process_method.call` → `run_after_callbacks` → block.apply OR raise. See [[ar-services]].
- **Service call (async)** → `.call_async` → `validate_serializable!` → `Steroids::AsyncServiceJob.perform_later(class_name:, params:, control:)` → worker `perform` → `new(**params.symbolize_keys)` → `exec_process` inline in the worker. See [[ar-async-dispatch]].
- **Error caught** → `exec_process` `rescue StandardError` → `errors.add` + `report_error!` → `Steroids::ErrorReporter.report_once!` → `Rails.error.report(handled: true, context:)`. See [[ar-errors-observability]].

## Cross-cutting modules

- **`MagicClass`** is intentionally near-empty — it exists to give services and types a shared root that bundles `NoticableMethods`. Comment in the file flags `inherited` propagation as a TODO.
- **`NoticableMethods`** is mixed into anything that needs the errors/notices/`notice` API. Currently: `MagicClass` (so services + types) — controllers reach the same surface via the service block's `noticable:` keyword.
- **`ServicableMethods`** is included by both `Services::Base` (for the `noticable_binding` helper) and `Controllers::Methods` (for the `service` class macro). The split lets a service nest a sub-service and have its errors merge into the parent.

## Naming conventions in use

- Files mirror Zeitwerk constants exactly (no overrides except the gem inflector at `lib/steroids.rb`).
- Class-level state lives in `@@…` (e.g. `@@wrap_in_transaction` global default) or `class_attribute` (e.g. `report_to_observability`, `wrap_in_transaction_override` for the per-class transaction opt-out).
- Instance-level steroids state uses `@steroids_*` (e.g. `@steroids_force`, `@steroids_skip_callbacks`, `@steroids_noticable_runtime`) to avoid collisions with subclass ivars.
- Specs live under `spec/` (RSpec, migrated from Minitest 2026-06-03), mirroring `lib/` — e.g. `spec/steroids/services/`, `spec/steroids/extensions/`. Async specs use ActiveJob's `:test` adapter.

## What's NOT here

- No DB migrations, no models, no views — Steroids is purely behavioral.
- No CLI, no generators, no rake tasks beyond the default test runner.
- No Sidekiq / Resque coupling. All async goes through `ActiveJob`.
- No telemetry transport — the observability seam delegates to `Rails.error` and stops there.
