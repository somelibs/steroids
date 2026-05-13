# Plan: Streaming Progress Notices from Services

**Created:** 2026-05-13
**Task:** Add a built-in mechanism in Steroids that lets services emit live progress messages on the go (`"processing A"`, `"processing B"`, `"doing this or that"`) — usable from both `.call` (sync) and `.call_async` (background) dispatch, with the UI subscribing on the controller's response page.
**Status:** Draft

---

## Summary

Add a `progress(message, **tags)` instance method on `Steroids::Services::Base` that publishes mid-execution status updates through a pluggable, configured publisher. Default publisher is a no-op so existing services don't change behavior. A shipped `ActionCable` adapter broadcasts to a per-`job_id` channel; a shipped `Test` adapter records emissions in-memory for assertions. The async service job threads its `job_id` into the instance so `progress` calls automatically scope to the right subscriber stream. A ring buffer on `noticable` preserves the last N entries so "open the page mid-job" shows recent history without depending on subscription replay.

The feature composes orthogonally with the existing per-call async + Hash `success_notice` work: `success_notice` is the **terminal** message (one-shot, sync vs async branches); `progress` is the **mid-stream** message (zero-or-more, identical service body in both modes).

---

## Knowledge Applied

### From Shared Knowledge
- **Pluggable adapter pattern** (telemetry seams already in Steroids — `Steroids::ErrorReporter` configured via `Rails.error` subscribers — same shape): publisher is configured at app boot; library stays transport-agnostic. Mirrors Rails' own logger/cache/active_job adapter conventions.
- **Service-author ergonomics > infra ergonomics**: the author writes `progress "..."` and never thinks about transport, job ids, sequence numbers, or rate limits — those live in the publisher / Base.

### From Library Knowledge
- **ActiveJob** exposes `job_id` inside `perform` — read once at the top of `Steroids::AsyncServiceJob#perform` and threaded into the service instance via `instance_variable_set(:@_steroids_job_id, …)` (same mechanism as the new `control:` plumbing).
- **ActionCable** `Turbo::StreamsChannel` / vanilla `ActionCable.server.broadcast(channel, payload)` — broadcast targets a string-named channel; consumers subscribe per `job_id` from the controller response.
- **NoticableMethods** already collects strings on the instance — extend with a `progress_log` ring buffer (default size 50, configurable) so the trail survives the publisher being unavailable.

### From Project Knowledge
- **Steroids `Base` post-2026-05-13** refactor: single `def process`, `.call` / `.call_async` / `.call_sync` entry points, no auto-detect, Hash-form `success_notice` with `sync:` / `async:` branches and `noticable.dispatch_mode`. The new `progress` API plugs into the same `noticable` object the success/error machinery already uses — no new state container.
- **Steroids ships an in-tree job** (`Steroids::AsyncServiceJob`) — same module convention applies for `Steroids::ProgressChannel` (in-tree, optional ActionCable channel that consuming apps mount when they want it).

---

## Prerequisites

- [x] Per-call async API landed (`.call` / `.call_async`).
- [x] Hash-form `success_notice` + `noticable.dispatch_mode` landed.
- [ ] Decide default `progress_log` ring size (proposed: 50, override via `Steroids.config.progress_log_max`).
- [ ] Decide on the publisher's drop policy under backpressure (proposed: coalesce-then-drop, with the latest message always preserved).

---

## Implementation Steps

### Step 1: Configuration seam
**Files:** `lib/steroids.rb` (or wherever `Steroids.config` is defined)

Add three config attributes:
- `progress_publisher` — defaults to `Steroids::Progress::Adapters::Null.new`. Anything responding to `publish(message:, job_id:, sequence:, tags:, service:)` qualifies.
- `progress_log_max` — defaults to `50`. Caps the per-service in-memory ring buffer.
- `progress_rate_limit_per_second` — defaults to `nil` (no rate limit at the library boundary; let the adapter decide). Optional global cap useful for chatty services.

### Step 2: Adapter interface + Null + Test adapters
**Files:** `lib/steroids/progress/adapters/null.rb`, `.../test.rb`, `lib/steroids/progress.rb`

```ruby
module Steroids
  module Progress
    module Adapters
      class Null
        def publish(message:, job_id: nil, sequence: nil, tags: {}, service: nil); end
      end

      class Test
        attr_reader :emissions
        def initialize; @emissions = []; end
        def publish(**payload); @emissions << payload; end
        def clear!; @emissions.clear; end
      end
    end
  end
end
```

`Test` adapter is the spec double — fixtures do `Steroids.config.progress_publisher = Steroids::Progress::Adapters::Test.new` in setup and assert against `.emissions`.

### Step 3: ActionCable adapter (optional, shipped in-tree)
**Files:** `lib/steroids/progress/adapters/action_cable.rb`, `app/channels/steroids/progress_channel.rb`

```ruby
module Steroids
  module Progress
    module Adapters
      class ActionCable
        # Broadcasts on "steroids:progress:<job_id>".
        # For sync dispatch (job_id == nil) this is a no-op — the noticable
        # ring buffer is the only sink.
        def publish(message:, job_id: nil, sequence:, tags: {}, service: nil)
          return unless job_id

          ::ActionCable.server.broadcast(
            "steroids:progress:#{job_id}",
            { message: message, sequence: sequence, tags: tags, service: service }
          )
        end
      end
    end
  end
end
```

`Steroids::ProgressChannel` (`app/channels/steroids/progress_channel.rb`) is a thin `ActionCable::Channel::Base` subclass that subscribes a client to `steroids:progress:<params[:job_id]>` — consuming apps either mount it directly or roll their own subscriber. Ship it; don't require it.

### Step 4: `progress` instance method on `Services::Base`
**Files:** `lib/steroids/services/base.rb`

```ruby
# Public: emit a mid-execution status message.
#   progress "Loading subscribers"
#   progress "Sent #{i}/#{n}", batch: i
#
# Stored on the noticable ring buffer for replay AND published through
# the configured Steroids.config.progress_publisher (default no-op).
def progress(message, **tags)
  @_steroids_progress_sequence ||= 0
  @_steroids_progress_sequence += 1

  noticable.progress_log.push(message, sequence: @_steroids_progress_sequence, tags: tags)

  Steroids.config.progress_publisher.publish(
    message: message,
    job_id: @_steroids_job_id,
    sequence: @_steroids_progress_sequence,
    tags: tags,
    service: self.class.name
  )
end
```

`progress` is public — service authors call it from their `process` body. No transport branching, no `if async`. Sync callers get a `nil` `job_id` → the cable adapter no-ops while the noticable ring still records the trail.

### Step 5: `noticable.progress_log` ring buffer
**Files:** `lib/steroids/support/noticable_methods.rb`

Extend `NoticableRuntime` (or its collection) with a `progress_log` reader that returns a bounded `Steroids::Progress::RingBuffer` capped at `Steroids.config.progress_log_max`. Each entry: `{ message:, sequence:, tags:, at: }`. Exposed alongside `notice` / `errors` so block callbacks can read it:

```ruby
service.call_async(...) do |service, **|
  service.noticable.progress_log.last(5).each { |entry| … }
end
```

### Step 6: Thread `job_id` into the service instance
**Files:** `app/jobs/steroids/async_service_job.rb`

Already passes `control:` into the instance — add `instance_variable_set(:@_steroids_job_id, self.job_id)` alongside it. Sync `.call` leaves `@_steroids_job_id` as `nil` — `progress` handles either case.

### Step 7: Optional rate limit at the Base boundary
**Files:** `lib/steroids/services/base.rb`

If `Steroids.config.progress_rate_limit_per_second` is set, `progress` short-circuits emissions exceeding the cap (the noticable ring still records them — only the publisher is throttled). Default `nil` = no library-level throttling. Adapters can apply their own coalescing on top.

### Step 8: README + AGENTS + CHANGELOG
**Files:** `README.md`, `AGENTS.md` (symlinked to `CLAUDE.md`), `CHANGELOG.md`

- README: a new "Progress / live status from services" section under Async Services, with the canonical example (loading subscribers loop).
- AGENTS: the same example in the agent reference.
- CHANGELOG: an "Added" entry under `[Unreleased]` enumerating the public API (`progress`, `progress_publisher` config, `progress_log_max`, `progress_rate_limit_per_second`, the three adapters, `Steroids::ProgressChannel`).

---

## Testing Strategy

- [ ] **`progress` no-publisher default** — when `Steroids.config.progress_publisher` is Null, calling `progress("msg")` does not raise and records to the ring.
- [ ] **Sync dispatch records to ring, doesn't broadcast** — Test adapter receives a `nil` `job_id` (or, if we choose: nothing at all — confirm the decision in Step 3's no-op branch).
- [ ] **Async dispatch broadcasts with job_id** — invoke through `Steroids::AsyncServiceJob.perform_now` with a stubbed `job_id`; assert the Test adapter captured emissions with that id, in order, with monotonically increasing sequence numbers.
- [ ] **Ring buffer caps at `progress_log_max`** — push N+1 entries, expect oldest one dropped.
- [ ] **Block callback can read progress_log** — sync `.call_sync(…) do |service, …|` reads `service.noticable.progress_log`.
- [ ] **Rate limit honored when set** — config the cap, fire faster than the cap, assert publisher receives at most cap-per-second; ring still has all entries.
- [ ] **Tags forwarded verbatim** — `progress("msg", batch: 3)` → adapter receives `tags: { batch: 3 }`.
- [ ] **No coupling to ActionCable** — load the gem without ActionCable available, run the Null + Test adapter tests; verify no `NameError`. (The ActionCable adapter requires `actioncable` lazily so consuming apps without it still work.)
- [ ] **Worker round-trip** — `AsyncServiceJob.perform_now(class_name: …, params: …)` makes the worker-side service's `progress` calls land in the Test adapter with the job's `job_id`.

---

## Considerations

- **Backpressure / ordering**: ActionCable does not guarantee delivery order across reconnects. The publisher contract includes a monotonic `sequence:` so consumers can dedupe + reorder client-side. Coalesce policy lives in the adapter, not in `Base` — the library shouldn't decide that subscribers care more about "latest" or "lossless"; that's app-domain.
- **Sync still records**: callers using `.call` on a slow operation may want progress too (a long inline import, a CLI script). Keeping the ring buffer + Null-adapter contract uniform means service code is transport-agnostic.
- **Don't broadcast errors as progress**: errors go through `noticable.errors` / `report_error!` / `Rails.error.report`. `progress` is strictly informational. Make this explicit in the README.
- **Don't broadcast on `before_process`/`after_process` callbacks unless the author opts in** — callbacks run for every dispatch; surfacing them would spam every service's UI. The author calls `progress` explicitly when they want emission.
- **`progress` is NOT a state container**: each call is a discrete event, never a "current step" override. Consumers wanting "the current step" should read `noticable.progress_log.last` themselves.
- **GlobalID-aware records as tags**: `tags: { user: persisted_user }` should serialize fine (ActiveJob handles AR records via GlobalID). Procs/IO still raise — same contract as `.call_async` arg validation, applied to the tags hash inside the publisher boundary.
- **Optional Sidekiq sidecar**: a future extension could persist the latest progress entry to a Redis key keyed by `job_id` for `GET /jobs/:id/progress` polling endpoints. Out of scope for v1.

---

## Out of Scope (deferred)

- A `GET /jobs/:id/progress` polling endpoint / generic mini-API.
- Server-side subscribers (only the browser/cable consumer is covered in v1).
- Cross-service stream composition ("parent service's progress includes nested services' progress"). Nice-to-have, not load-bearing.
- Built-in throttling smarter than per-second cap — adapters can layer it.
- Pusher / Ably / SSE adapters — shipped only as docs ("here's the contract, here's a 15-line example"). Library stays Rails-cable-only in-tree for v1.

---

## Notes

Pairs naturally with the just-landed Hash-form `success_notice`: `success_notice sync:/async:` describes the terminal state of the dispatch, `progress` narrates the middle. Same service body works in both modes. The `service` macro in `ServicableMethods` already handles the async block-callback preview correctly — no changes needed there for v1, but a follow-up could surface `noticable.progress_log` in the preview's `flash_key`-equivalent slot for UIs that want to show "queued — last 3 steps: …".

Estimated size: ~150 lines net across `lib/steroids/services/base.rb`, `lib/steroids/support/noticable_methods.rb`, three new files under `lib/steroids/progress/`, `app/channels/steroids/progress_channel.rb`, and the AsyncServiceJob threading line. Plus tests (~120 lines) and the doc updates.
