# ar-services — Service objects (`Steroids::Services::Base`)

Source: `lib/steroids/services/base.rb`.

## Authoring contract

```ruby
class MyService < Steroids::Services::Base
  success_notice "Operation completed"           # String OR { sync:, async: } Hash
  before_process  :validate!
  after_process   :cleanup
  # async_only!                                  # opt-in: forbids inline `.call`

  def initialize(user:, data:)
    @user = user
    @data = data
  end

  def process
    drop!("invalid") if @data.blank?
    @user.update!(@data)
  rescue ActiveRecord::RecordInvalid => e
    errors.add("update failed", e)
  end

  def rescue!(exception) = nil  # optional — catches inside exec_process
  def ensure!             = nil  # optional — always runs
end
```

**One `process` per class.** No `async_process`. The class doesn't decide sync vs async — the **caller** does (see [[ar-async-dispatch]]).

## Lifecycle

`exec_process` is the single execution path used by both `.call` (inline) and `Steroids::AsyncServiceJob#perform` (worker):

```
exec_process
  ├── process_wrapper                            # opens ActiveRecord::Base.transaction (if @@wrap_in_transaction)
  │     ├── run_before_callbacks                 # unless @steroids_skip_callbacks
  │     │     ├── self.class.steroids_before_callbacks.each → send_apply
  │     │     └── send_apply(:before_process)
  │     ├── process_method.call                  # the user's `def process`
  │     │     └── drop! if errors.any? && !block_given?
  │     └── run_after_callbacks(outcome)
  │           ├── send_apply(:after_process, outcome)
  │           └── self.class.steroids_after_callbacks.each
  ├── rescue StandardError                       # → errors.add, report_error!, then either rescue!(e) or raise
  └── ensure                                      # → ensure! if defined
```

If `process_wrapper` catches the internal `RuntimeError` (subclass of `Steroids::Errors::Base`) — used as the `drop!` signal — it appends `error.message` to `errors` and returns. Other `StandardError`s bubble out of `process_wrapper` and are caught by `exec_process`'s outer rescue.

## Flow control: `drop!`

```ruby
drop!("custom message")
drop!(message: "custom message")  # same thing, keyword form
```

Raises an internal `Steroids::Services::Base::RuntimeError` with `errors:` and `log: true`. Caught by `process_wrapper`, which appends the message to the noticable errors collection.

`drop!` is a **no-op** when `@steroids_force` is true (set via `.call(force: true)` or `call_async(force: true)`). That lets a caller force-complete a service even when its `process` would otherwise abort.

## Control flags vs init args

`Steroids::Services::Base::CONTROL_OPTIONS = %i[force skip_callbacks].freeze`

The class-level `.call` / `.call_async` partition keyword args:
- **Control opts** (in the set above) → routed to `#call(**ctrl)` / `AsyncServiceJob#perform(control:)`.
- **Init opts** (everything else) → flow into `new(**init)`.

So this works:

```ruby
MyService.call(user: u, data: d, force: true, skip_callbacks: true)
# → MyService.new(user: u, data: d).call(force: true, skip_callbacks: true)
```

## `async_only!`

Class-level marker. When set, `.call` / `.call_sync` raise `Steroids::Services::Base::AsyncOnlyError` with a message pointing the developer at `.call_async`. Use for work that must never block a request thread.

## Callbacks

`before_process`, `after_process` are class-level protected methods that append onto `steroids_before_callbacks` / `steroids_after_callbacks`. Both are also valid as **instance methods** with those exact names (`def before_process; …; end`) — `run_before_callbacks` always invokes the instance method via `send_apply(:before_process)` after running the class-registered chain.

Both forms use `send_apply` from [[ar-extensions#object]], which arity-matches kwargs to the receiver's signature — so you can declare `def after_process(outcome)` or `def after_process` interchangeably.

## Block form

```ruby
MyService.call(user: u) do |service, outcome, noticable:, flash_key:|
  redirect_to path, flash_key => service.notice
end
```

When a block is passed:
- The outer `raise self.noticable.to_exception` is **skipped** (the block decides how to surface errors).
- The block is invoked via `Method#apply` (arity-aware) with `service`, the `process` return value, `noticable:`, and `flash_key:`.
- `drop!` is **not** auto-triggered when errors accumulate (the block sees them and decides).

Without a block, `errors.any?` after `process` triggers `drop!`, which surfaces as a raised `noticable.to_exception` to the caller.

## Transactions

`@@wrap_in_transaction = true` by default — `process_wrapper` wraps `process` in `ActiveRecord::Base.transaction`. To disable globally, override the class variable in an initializer. There is no per-service knob (yet).

A `drop!` inside `process` raises a Steroids `RuntimeError` which is caught **inside** `process_wrapper`, so the transaction **rolls back** before the rescue runs. Same for any other `StandardError` (it propagates out of `process_wrapper`, rolling back the transaction, then hits `exec_process`'s outer rescue).

## Observability hook: `report_error!`

Private instance method on `Services::Base`. Called automatically by `exec_process` for every rescued `StandardError`. Forwards to `Steroids::ErrorReporter.report_once!` with `service: self.class.name` and any extra `**context` tags. Skipped if `exception.class.report_to_observability == false`. See [[ar-errors-observability]].

Aliased as `report_to_observability!` for explicit calls from inside a service's own rescue block.

## Testing

```ruby
RSpec.describe MyService do
  it "succeeds" do
    s = MyService.new(user: u, data: d)
    s.call
    expect(s).to be_success
    expect(s.notice).to eq("Operation completed")
  end
end
```

Or via the class entry point with a block. The test suite (`test/services/async_service_test.rb`) uses ActiveJob's `:test` adapter to assert enqueue behavior. See [[ar-async-dispatch]] for the async test fixtures.
