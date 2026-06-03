# biz-features — Steroids feature catalog

A flat list of every user-facing capability the gem ships, with pointers into the architecture docs.

## Service objects

- **`Steroids::Services::Base`** — base class for service objects. One `def process` per class.
- **Lifecycle hooks** — `before_process`, `after_process`, `rescue!`, `ensure!`.
- **Flow control** — `drop!(message)` halts execution; auto-`drop!` when `errors.any?` after `process`.
- **Implicit transaction** — `process` runs inside `ActiveRecord::Base.transaction`. Global default via `@@wrap_in_transaction`; per-class opt-out via the `wrap_in_transaction false` macro (for services that mainly hit an external API).
- **Control flags** — `force:` (bypass `drop!`), `skip_callbacks:` (skip before/after hooks).
- **`async_only!`** — class-level marker that forbids inline `.call`/`.call_sync`.

Detail: [[ar-services]].

## Per-call async dispatch

- **`.call(*, **)`** / **`.call_sync(*, **)`** — run `process` inline.
- **`.call_async(**)`** — enqueue `Steroids::AsyncServiceJob`. Keyword args only. Validates serializability at the call site (raises `NonSerializableArgumentError` with dotted paths to each offender). `control:` keyword (forwards `force:`/`skip_callbacks:`) is forwarded to the worker.
- **`Steroids::AsyncServiceJob`** — re-instantiates the service from `class_name` + serialized `params` and calls `exec_process` inline inside the worker.
- **`success_notice`** — String or `{ sync:, async: }` Hash; resolver picks the matching branch via `noticable.dispatch_mode`.

Detail: [[ar-async-dispatch]].

## Errors & notices (Noticable)

- **`NoticableCollection`** — `errors.add("message", exception=nil)`, `notices.add("message")`. Not ActiveRecord-style: just strings, no `:base` attribute key.
- **`NoticableRuntime`** — instance-side wrapper exposing `errors`, `notices`, `notice`, `message`, `success?`, `errors?`, `flash_key`, `to_exception`, `dispatch_mode`.
- **`success_notice` resolver** — per-mode messages (sync / async) with fallbacks.

Detail: [[ar-noticable]].

## Controller integration

- **`service :name, class_name:, async: false, **opts`** macro (in `ServicableMethods`) — declares a controller helper that calls `.call` (inline) or `.call_async` (enqueue), with a block form that yields either the real instance (sync) or a fresh preview instance with `dispatch_mode = :async` (async).
- **`Steroids::Controllers::Methods`** — concern that pulls in `RespondersHelper`, `SerializersHelper`, and `ServicableMethods`. Provides `respond_with` with JSON serializer / pagination / scopes.
- **`RespondersHelper#respond_with`** — JSON-format-aware renderer with `default_serializer`, `paginate:`, scoping.

Detail: [[ar-controllers]].

## Error classes & observability

- **`Steroids::Errors::Base`** — extends `StandardError`. `class_attribute :default_message, :default_status, :report_to_observability`. Mixes in `Context` (HTTP status mapping) and `Quotes` (random quote for default error pages).
- **HTTP error subclasses** — `BadRequestError`, `ConflictError`, `ForbiddenError`, `InternalServerError`, `NotFoundError`, `NotImplementedError`, `UnauthorizedError`, `UnprocessableEntityError`, `GenericError`.
- **`Steroids::ErrorReporter.report_once!(exception, **context)`** — idempotent forwarder to `Rails.error.report`. Marks the exception with `@_steroids_reported`. Degrades to a no-op when `Rails.error` is unavailable. Never raises.
- **`Steroids::Services::Base#report_error!`** — auto-invoked by `exec_process` for every rescued `StandardError`. Skipped when `report_to_observability == false` on the error class.

Detail: [[ar-errors-observability]].

## Logging

- **`Steroids::Logger`** — wraps `Rails.logger` with colorized (`rainbow`) formatting for exceptions, backtraces, errors-arrays, context tags, and causes. `Steroids::Logger.print(obj_or_exception, verbosity:, format:)`.

## Type system

- **`Steroids::Types::SerializableType`** — `attributes`, `attribute`, ActiveModel::Model + Serialization.
- **`Steroids::Types::Base`** — adds `requires(attr)`, `validate_required!`, `import(options, object)`, `missing_attributes`.

Detail: [[ar-types-serializers]].

## Serializers

- **`Steroids::Serializers::Base`** (ActiveModel::Serializer subclass) + **`Methods`** concern — nil-pruning `serializable_hash`, `parse_options` that coerces `params` strings to `true`/`false`/Integer, `attributes(*attrs, **opts)` with positional-array support.
- **`Steroids::ErrorSerializer`** (in `app/serializers/`) — JSON for an error response.

## Ruby core extensions

- **`Object`** — `instance_apply`, `send_apply`, `send_apply!`, `try_method`, `typed`/`typed!`, `boolean?`, `ifnil`, `marshallable?`, `serializable?`, `deep_serialize`. Custom `freeze` that materializes `steroids_attributes_set` first.
- **`Hash`** — `fetch_any(*keys)`.
- **`Array`** — `cast(value, indifferent_access=false)` (raises `ElementNotFound` if missing), `find_map(&block)`.
- **`Method` / `Proc`** — `apply`, `dynamic_arguments_for`, `dynamic_options_for`, `arguments`, `options`, `spread?`, `rest?` (arity-aware dynamic dispatch).
- **`Class`** — `attribute(name, default:, type:, allow_nil:)`, `runtime_methods`, `runtime_instance_methods`, `delegate_alias`, `forward_methods_to`, `try_delegate`, `proxy`, `build_anonymous`.
- **`Module`** — `grundclass`, `create_namespace`, private `mixin`/`mixin_alias`.

Detail: [[ar-extensions]].

## In-flight work

- **Streaming progress notices** — design doc at [[plans/@2026-05-13-01-streaming-progress-notices]] (not yet implemented). Will add a `progress(message, **tags)` API on services + pluggable publisher (default no-op, ActionCable adapter shipped, Test adapter for assertions). Composes with the per-call dispatch + Hash `success_notice` model.
