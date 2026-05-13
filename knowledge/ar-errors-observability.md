# ar-errors-observability — Error classes & APM-agnostic reporting

Sources: `lib/steroids/errors.rb`, `lib/steroids/errors/base.rb`, `lib/steroids/errors/context.rb`, `lib/steroids/errors/quotes.rb`, `lib/steroids/error_reporter.rb`, `lib/steroids/services/base.rb#report_error!`.

## Error hierarchy

```
StandardError
  └─ Steroids::Errors::Base
       (includes ActiveModel::Serialization, Context, Quotes)
       │  class_attribute :default_message  = "Oops, something went wrong (Unknown error)"
       │  class_attribute :default_status   = :internal_server_error
       │  class_attribute :report_to_observability = true
       ├─ GenericError                  # status: :generic_error
       ├─ BadRequestError               # status: :bad_request
       ├─ ConflictError                 # status: :conflict
       ├─ ForbiddenError                # status: :forbidden
       ├─ InternalServerError           # status: :internal_server_error
       ├─ NotFoundError                 # status: :not_found
       ├─ NotImplementedError           # status: :not_implemented
       ├─ UnauthorizedError             # status: :unauthorized
       ├─ UnprocessableEntityError      # status: :unprocessable_content
       ├─ (in Services::Base) RuntimeError        # internal drop! signal
       ├─ (in Services::Base) AsyncOnlyError
       ├─ (in Services::Base) NonSerializableArgumentError
       └─ (in NoticableMethods) RuntimeException
```

## `Steroids::Errors::Base#initialize`

```ruby
OTPIONS = %i[status message errors code cause context log]   # (sic; typo preserved)

def initialize(message_string = nil, **options)
  @caller = caller
  extended_options = options.select{|key|OTPIONS.include?(key)}
  splat_options    = options.select{|key|!OTPIONS.include?(key)}
  define_instance_variables_for(message_string, **extended_options)
  super(**splat_options, message: message, cause: @cause)
  set_backtrace(@cause&.backtrace || backtrace_locations || caller)
  extended_options.fetch(:log, false) ? self.log! : self.quiet_log
end
```

Every Steroids error logs **something** at construction time — either via `Steroids::Logger.print(self)` (`log: true`) or a one-line "quiet" log. `cause_message` walks an optional `cause:` chain, skipping causes already marked `logged == true` so dupes don't fill the log.

Surface: `id`, `message`, `cause`, `code`, `status`, `errors`, `record`, `context`, `timestamp`, `logged`. The `Context` concern (in `errors/context.rb`) maps to HTTP status via Rails' `rescue_responses`; the `Quotes` concern (in `errors/quotes.rb`) provides a cached random quote for default error pages (file at `lib/resources/quotes.yml`).

## The reporter seam

`lib/steroids/error_reporter.rb`. A thin, intentionally minimal module:

```ruby
Steroids::ErrorReporter.report_once!(exception, **context)
```

- **Idempotent.** Stores `@_steroids_reported = true` on the exception object via `instance_variable_set`. Repeat calls (e.g. controller rescue, then service rescue) are no-ops.
- **Best-effort delivery.** Calls `Rails.error.report(exception, handled: true, context: context)`. If `Rails.error` is undefined or doesn't respond to `:report`, returns false silently. If the underlying subscriber raises, the reporter `warn`-logs and swallows — observability **never** disrupts the calling rescue path.
- **No APM coupling.** Steroids doesn't know about AppSignal/Sentry/Honeybadger/etc. The host app subscribes (or the APM gem auto-subscribes), and `Rails.error.report` fans out.

## Automatic wiring inside services

`Steroids::Services::Base#exec_process` (in `services/base.rb`) calls `report_error!(outcome)` for every `rescue StandardError`. The implementation:

```ruby
def report_error!(outcome, **context)
  return if outcome.respond_to?(:report_to_observability) && outcome.report_to_observability == false
  Steroids::ErrorReporter.report_once!(outcome, service: self.class.name, **context)
end
alias_method :report_to_observability!, :report_error!
```

So:
- **Steroids errors that opt out** (set `self.report_to_observability = false` on the class) → skipped.
- **Steroids errors that don't opt out** → reported, even though they're "internal."
- **Raw 3rd-party exceptions** → reported (since they don't respond to `report_to_observability`).
- **`drop!`'s internal `RuntimeError`** → has `report_to_observability` true by default, but it never reaches `exec_process`'s outer rescue (it's caught inside `process_wrapper`).

Use the alias `report_to_observability!` when you handle an exception inside your service's own `rescue` and still want the APM hit:

```ruby
def process
  do_work
rescue HTTP::TimeoutError => e
  report_to_observability!(e, endpoint: api_url)
  errors.add("upstream timed out", e)
end
```

## When to flip `report_to_observability = false`

Subclass your "expected" / user-flow errors and opt out:

```ruby
class ValidationError < Steroids::Errors::Base
  self.default_status = :unprocessable_content
  self.report_to_observability = false   # keep APM dashboards focused on infra failures
end
```

This is documented in [[wrapups/@2026-05-11-01-error-reportability-observability-seam]] which introduced the seam.

## ErrorSerializer

`app/serializers/steroids/error_serializer.rb` (subclass of `Steroids::Serializers::Base`). Renders an error as JSON for API responses. Conditionally includes the raw exception only when not in production (the conditional `:exception` attribute collapses dev/test extras — see the 2026-05-11 wrapup).
