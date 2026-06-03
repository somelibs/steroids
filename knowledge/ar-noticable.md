# ar-noticable — Errors, notices & dispatch-mode messaging

Source: `lib/steroids/support/noticable_methods.rb`.

## Why it exists

Rails apps already have `ActiveRecord::Errors`, but it has two problems for service objects:

1. It's keyed by attribute (`errors.add(:base, …)`) — useless for cross-cutting service failures.
2. It can't carry the original exception alongside the user-facing message.

`Steroids::Support::NoticableMethods` replaces it with a string-keyed collection that:
- Accepts `errors.add("message", exception=nil)` — first arg is **always** a message string.
- Has a parallel `notices` collection for non-error info.
- Exposes `notice` / `message` (auto-resolves "if errors → error messages; else → success notice").
- Knows about dispatch mode (sync vs async) so the success notice can vary per branch.

## Concrete classes

### `NoticableCollection` (one for `:errors`, one for `:notices`)

```ruby
errors.add("Validation failed")                  # message only
errors.add("Sync failed", exception)             # message + original exception
errors << "shorthand"                            # alias for add
errors.merge(other_collection)
errors.any?
errors.full_messages                             # joins all messages with "\n"
errors.messages                                  # alias for full_messages
```

Internally each entry is a `{ message:, exception: }` Hash. The `message.typed!(String)` call in `add` enforces that the first arg really is a String — if you pass an Exception as the first arg, it auto-extracts `exception.message` and stores the exception as the message, with `nil` for `exception`. (See lines 43–52 of `noticable_methods.rb` for the exact branching.)

Collection types come from a frozen list: `NOTICABLE_TYPES = %i[errors notices]`. The constructor casts the type via `Array#cast` (from [[ar-extensions]]), raising `ArrayExtension::ElementNotFound` if you pass anything else.

### `NoticableRuntime` (one instance per service / noticable host)

Holds **both** collections plus dispatch-mode state. Lazy-built per instance:

```ruby
def noticable
  @steroids_noticable_runtime ||= NoticableRuntime.new(
    self,
    success_notice: self.class.steroids_noticable_notice
  )
end
delegate :notice, :errors, :notices, :success?, :errors?, :flash_key, to: :noticable
```

Public API on the runtime:

| Method | Returns |
|--------|---------|
| `errors` / `notices` | The two `NoticableCollection`s |
| `errors?` / `success?` | `errors.any?` / `!errors?` |
| `notice` / `message` / `full_messages` | If errors → `errors.full_messages`; else → `notices.full_messages.presence || resolved_success_notice` |
| `flash_key` | `:alert` when errors, else `:notice` (for Rails flash) |
| `to_exception` | A `NoticableMethods::RuntimeException` carrying `full_messages` + the first stored exception as `cause` |
| `merge(other)` | Appends another noticable's errors + notices |
| `dispatch_mode` / `dispatch_mode=` | `:sync` (default) or `:async`, validated against `DISPATCH_MODES` |

## `success_notice` resolution

The `success_notice` class macro takes a String OR a Hash. Resolution happens lazily in `resolved_success_notice` based on `dispatch_mode`:

| Declaration | `:sync` resolves to | `:async` resolves to |
|-------------|---------------------|----------------------|
| `success_notice "Saved"` | `"Saved"` | `"Saved (async)"` (suffix `" (async)"`) |
| `success_notice sync: "Saved", async: "Queued"` | `"Saved"` | `"Queued"` |
| `success_notice sync: "Saved"` | `"Saved"` | `"Queued for background processing."` (generic async fallback) |
| `success_notice async: "Queued"` | `"<ClassName humanized> succeeded"` | `"Queued"` |
| `success_notice` not declared | `"<ClassName humanized> succeeded"` | `"Queued for background processing."` |

Constants:
- `ASYNC_PLAIN_SUFFIX = " (async)"`
- `ASYNC_FALLBACK_NOTICE = "Queued for background processing."`

`dispatch_mode` is flipped to `:async` by:
1. The `service :name, …, async: true` macro on a preview instance (so the controller block reads the right message) — see [[ar-services]] / `servicable_methods.rb`.
2. Test code / library internals that want the async branch surfaced.

It is **not** automatically flipped inside `AsyncServiceJob#perform` (the worker doesn't currently re-resolve the notice — the message is a controller-side concern, surfaced at enqueue time).

## Two key gotchas

1. **`errors.add(:base, "msg")` does NOT work.** First arg is the message. There is no attribute key. Trying to pass a Symbol triggers `message.typed!(String)` and raises `TypeError`.
2. **No `errors.full_messages` joining like AR.** It joins with `\n`, not commas, because the typical consumer is a flash message or an error page. If you want a list, call `errors.map { |e| e[:message] }` directly.

## Related

- The `RuntimeException` class on this module (`< Steroids::Errors::Base`) is what `to_exception` returns. It is **distinct** from the `RuntimeError` class in `Services::Base` used internally by `drop!`.
- `flash_key` is what the controller block's `flash_key:` kwarg is bound to — see [[ar-services]] block form.
- `dispatch_mode` interplay with `success_notice` is exercised by the async dispatch specs (`spec/steroids/services/async_dispatch_spec.rb`, `spec/steroids/support/servicable_async_spec.rb`) — fixtures covering Hash-full / String-suffix / partial-Hash-fallback / no-notice-fallback exercise all four rows of the table above.
