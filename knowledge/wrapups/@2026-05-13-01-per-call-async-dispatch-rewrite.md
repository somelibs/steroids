# Wrapup: Per-call async dispatch rewrite

**Date:** 2026-05-13
**Branch:** develop
**Baseline:** previous wrapup `@2026-05-11-01-error-reportability-observability-seam.md` (recorded HEAD `6c2318d`; commit landed as `5429c01`)
**HEAD at wrapup:** 5429c0195e34a7a5ba37365ed7be1c9cbc7fafd1
**Note:** —

---

## Summary
Single uncommitted batch — no new commits since the last wrapup. This change reworks the async story end-to-end: `async_process` and the `Sidekiq.server?` auto-detection heuristic are gone, replaced by per-invocation `.call` / `.call_sync` / `.call_async` entry points on `Steroids::Services::Base`. `.call_async` now performs call-site serializability validation with dotted-path errors; `success_notice` gained per-mode (`:sync` / `:async`) Hash form; the `service` macro grew `async: true`; `AsyncServiceJob#perform` gained a `control:` kwarg. The async test file was rewritten top-to-bottom for the new model (16 new tests). Test suite improved from **2 failures / 6 errors** → **0 failures / 6 errors** — the 2 prior async failures are resolved, the same 6 service-call-contract errors documented as pre-existing in the previous wrapup remain (still out of scope for a wrapup).

## What We Did
- **`lib/steroids/services/base.rb` — dispatch rewrite.** Removed `async?`, `validate_process_definition!`, `AmbiguousProcessMethodError`, `AsyncProcessArgumentError`, the new-time `@_steroids_serialized_init_options` capture, `schedule_process`, and `async_exec?`. Replaced with:
  - Class-level `.call` / `.call_sync` (alias) → splits options into init opts vs `CONTROL_OPTIONS` (`force:`, `skip_callbacks:`), instantiates the service, runs `exec_process` inline. Raises `AsyncOnlyError` for `async_only!` services.
  - Class-level `.call_async` → rejects positional args, validates serializability of init opts via `collect_unserializable` (walks Hash/Array nesting, accumulates *all* offenders with dotted paths), then `Steroids::AsyncServiceJob.perform_later(class_name:, params:, control:)`.
  - New `PRIMITIVE_SERIALIZABLE` allowlist (String/Symbol/Numeric/Bool/Nil/Date/Time/DateTime); `BigDecimal`, persisted `ActiveRecord::Base`, and any `to_global_id`-responder are also accepted. Anonymous classes, Procs, IO, unpersisted records → caught.
  - New `AsyncOnlyError` and `NonSerializableArgumentError` classes with descriptive `default_message`s.
  - Instance `#call` simplified to kwargs-only; `exec_process` no longer accepts forwarded args (callbacks were the only consumer and they don't receive any either now).
- **`app/jobs/steroids/async_service_job.rb`** — `perform` now takes `control: {}` and forwards `force:` / `skip_callbacks:` into the worker-built instance via `instance_variable_set` before invoking `exec_process`. Symbolizes both `params` and `control` keys for ActiveJob round-tripping.
- **`lib/steroids/support/noticable_methods.rb`** — `NoticableRuntime` gained `dispatch_mode` (default `:sync`, validated against `DISPATCH_MODES = %i[sync async]`), `resolved_success_notice`, and `mode_fallback_notice`. `success_notice` accepts:
  - **String** — sync uses as-is; async appends `" (async)"`.
  - **Hash** keyed by `:sync` / `:async` — picks the matching key; missing key falls back to `"Queued for background processing."` (async) or `"<ClassName> succeeded"` (sync).
- **`lib/steroids/support/servicable_methods.rb`** — `service :name, class_name:, async: true` now calls `.call_async` and yields a `preview` instance (fresh `service_class.new(*args, **merged_options)`) with `dispatch_mode = :async` to the block, so controllers do `redirect_to ..., service.flash_key => service.notice` symmetrically across sync/async. Removed the old `async:` keyword propagation to sub-services (no longer meaningful in the new model).
- **`test/services/async_service_test.rb`** — full rewrite (~310 lines). New fixtures (`MultiplyService`, `MustBeAsyncService`, `CallbackService`, `HashNoticeService`, `StringNoticeService`, `PartialHashNoticeService`, `NoNoticeService`). New coverage: `.call` runs inline / doesn't enqueue; `.call_sync` alias; `.call_async` enqueues `Steroids::AsyncServiceJob` with correct payload; `control:` forwarded; positional args refused; `NonSerializableArgumentError` lists each offender + nested dotted paths; primitives accepted; `async_only!` enforcement on `.call`/`.call_sync`/`.call_async`; per-mode notice resolution (4 cases: Hash full, String suffix, partial Hash fallback, no-notice fallback); worker round-trip via `perform_now` (init args captured via singleton alias trampoline; `control: { skip_callbacks: true }` skips before_process). Uses ActiveJob `:test` adapter via `setup`/`teardown`.
- **`AGENTS.md` / `README.md` / `CHANGELOG.md`** — rewritten "Async Services" sections, dispatch resolution table for `success_notice`, control-flag docs, updated `service` macro example. `CHANGELOG.md` now headlines the breaking change under `## [Unreleased]` with full migration notes; the prior wrapup's observability bullets are preserved.
- **`knowledge/plans/@2026-05-13-01-streaming-progress-notices.md` (new)** — forward-looking design doc for a built-in `progress(message, **tags)` API on services (composes with the per-call dispatch work; one terminal `success_notice`, zero-or-more mid-stream `progress` messages). Plan only, no code changes. Captured here for traceability — see the file itself for the design.

## Current Status
- New dispatch API (`call` / `call_sync` / `call_async`) — complete, covered by `test/services/async_service_test.rb` (16/16 passing).
- Serializability validation — complete and covered (offender list, dotted paths, primitives accepted, positional rejection, AR / GlobalID acceptance covered implicitly by accepting the `PRIMITIVE_SERIALIZABLE` cases).
- Per-mode `success_notice` resolution — complete and covered (4 cases passing).
- `async_only!` enforcement — complete and covered.
- `AsyncServiceJob` worker round-trip with `control:` — complete and covered (`perform_now`).
- `service ..., async: true` controller helper — wired and documented, **no test coverage in this batch.** Manual review only.
- Test suite: **102 runs, 242 assertions, 0 failures, 6 errors, 0 skips.** 6 errors are the same pre-existing service-call-contract errors documented in the prior wrapup — none introduced by this batch. The 2 async failures the prior wrapup recorded are *resolved* by the rewrite.

## Open Issues
- [ ] **6 service tests still error because `Base#call` raises on `errors.any?` when called *without* a block** (`lib/steroids/services/base.rb:51-52`). Affected: `BaseServiceTest#test_service_with_errors_returns_failure`, `#test_service_with_validation_errors_drops_execution`, `#test_drop!_halts_execution`; `ComprehensiveServiceTest#test_ensure!_always_runs`, `#test_service_returns_nil_when_errors_occur`, `#test_drop!_halts_execution_and_sets_errors`. **Pre-existing** — present before this batch; documented in the 2026-05-11 wrapup. Requires a deliberate decision on the service call contract (raise-on-error vs. return-and-check). Out of scope for this wrapup.
- [ ] **No test coverage for the `service ..., async: true` controller helper** (the `preview` block path in `lib/steroids/support/servicable_methods.rb:34-58`). The path is straight-line and small, but it's a public API surface — worth at least one happy-path integration test that asserts the job is enqueued *and* the block receives a preview with `dispatch_mode == :async` and the right async notice.
- [ ] **No test coverage for ActiveRecord `persisted?` / `to_global_id` branches** in `collect_unserializable`. Currently only Proc/IO/Hash/nested cases are exercised; the AR / GlobalID branches are reachable through normal usage but unverified in CI.

## Potential Issues / Risks
- **Breaking change.** Any service in a downstream app that still defines `def async_process` will silently *not run async* — `.call` will fail (no `process` method) and `.call_async` will enqueue then crash inside the worker. CHANGELOG.md headlines this; consider a one-shot `validate_process_definition!`-style detector that raises a clear `MissingProcessMethodError` ("did you mean to rename `async_process` to `process`?") to make the migration loud.
- **`.call_async(async_only_service)` doesn't raise inside `.call_async`** — `async_only!` is enforced only on the sync entry points. That's correct, but means *no* validation that a non-async-only service was actually intended for background dispatch. Probably fine.
- **`AsyncServiceJob.perform` skips `instance.call`**, going straight to `exec_process` via `send`. This bypasses the instance-level `#call`'s `ensure` branch (where `errors.any?` → raise) — which is the right call (a worker rescue path raising would just mark the job failed and re-queue) but means worker behaviour and inline behaviour diverge on errors. Worth a code comment in `perform` to make the intent explicit.
- **`control` kwarg is forwarded via `instance_variable_set`** in the worker. Works, but couples the job to instance-variable naming. A `Base#apply_control_options(control)` instance method would localize the coupling.
- **`collect_unserializable` runs every time `.call_async` is invoked.** For deep / large hashes this is a meaningful walk on the request thread. Not a problem today; worth knowing if a caller passes large payloads (unlikely — large payloads aren't job-serializable to start with).
- **No `.rubocop.yml`** — still no lint gate at all. Style enforced only by review.

## Pending / Left To Do
- [ ] Decide / land the service call-contract resolution (the 6 pre-existing errors). Whichever way: reconcile tests + `AGENTS.md` + `README.md`.
- [ ] Add at least one happy-path test for the `service ..., async: true` controller helper.
- [ ] Cover the AR-persisted / `to_global_id` branches of `collect_unserializable` with a small stub-based test.
- [ ] Consider a friendly `MissingProcessMethodError` to soften the `async_process` → `process` migration for downstream apps.

## Cleanup Needed
- [ ] `test/services/async_service_test.rb:273-281` — the `singleton_class.send(:alias_method, :new, ...)` round-trip in `test "Steroids::AsyncServiceJob.perform_now re-instantiates and runs the service"` is intricate. A tiny `class ConstructorSpy` or `Minitest::Mock` would read more straightforwardly. Cosmetic.
- [ ] `test/services/async_service_test.rb:299-306` — the `CallbackService.class_eval { define_method(:setup) { … } }` swap relies on test-order isolation; if `CallbackService` is reused later in this file (it isn't today), tracking would be muddled. Cosmetic.
- [ ] `test/errors/error_serializer_test.rb:10,13` — still redefining `env` (noted in prior wrapup as cosmetic; the warnings reappear in this run too).
- [ ] `lib/steroids/services/base.rb` lost its `*args` plumbing from `run_before_callbacks` — that's correct given that `exec_process` no longer accepts forwarded args, but verify no downstream `before_process` callbacks were relying on the old `*args, **options` signature. Likely fine because nothing in this repo passed args, but worth a grep in consuming projects.

## Next Steps
1. Land this batch as a single commit on `develop`.
2. Decide the service call contract (raise-on-error vs. return-and-check); update tests + `AGENTS.md` + `README.md` accordingly. This is the cleanup blocker that has now been carried across two wrapups.
3. Add the missing `service ..., async: true` controller-helper test.
4. Add stub-based coverage for `collect_unserializable`'s AR-persisted / `to_global_id` branches.
5. (Optional) Add the friendly `MissingProcessMethodError` migration hint.
6. (Optional) Add a `.rubocop.yml` so the project has any lint gate at all.

## Notes & Decisions
- Baseline is the recorded `HEAD at wrapup` from the prior wrapup file (`6c2318d`), which actually landed as commit `5429c01` ("Wrapup 2026-05-11: error reportability & observability seam"). No new commits since — this entire batch is uncommitted working-tree work.
- Did **not** attempt to fix the 6 pre-existing call-contract errors. Same reasoning as the prior wrapup: they require a design decision, not a code fix.
- Kept the `service ..., async: true` block-fires-immediately design (worker errors do not surface to the request). Alternative would be to wait on the job in dev/test — explicitly rejected because mixing wait-modes per environment is exactly the auto-detection footgun this rewrite exists to remove.
- `.call_async` returns the job handle from `Steroids::AsyncServiceJob.perform_later(...)`. Callers can attach it as a Linear/Slack reference, but no internal code relies on the return type.
- `ActiveJob::Base.queue_adapter` is set to `:test` in the rewritten test setup and restored in teardown — does not touch global app config when run as part of a host app's suite.

## Lint & Test Status
- RuboCop: n/a — no `.rubocop.yml` / rubocop in the bundle. No lint gate exists.
- `bundle exec rake test`: ⚠️ **102 runs, 242 assertions, 0 failures, 6 errors, 0 skips.** All 6 errors are pre-existing (same set the 2026-05-11 wrapup documented, minus the 2 async failures which this batch resolves). No new failures introduced.

---

## Changed Files (since baseline `5429c01`, all uncommitted)
```
 AGENTS.md                                                                  |  73 +++--
 CHANGELOG.md                                                               |  26 +-
 README.md                                                                  | 116 ++++++--
 app/jobs/steroids/async_service_job.rb                                     |  15 +-
 knowledge/plans/@2026-05-13-01-streaming-progress-notices.md               | (new — design doc, no code)
 knowledge/wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite.md        | (new — this wrapup)
 lib/steroids/services/base.rb                                              | 223 +++++++++-----
 lib/steroids/support/noticable_methods.rb                                  |  47 ++-
 lib/steroids/support/servicable_methods.rb                                 |  48 ++-
 test/services/async_service_test.rb                                        | 461 ++++++++++++++++++-----------
 8 code files changed, 692 insertions(+), 317 deletions(-) + 2 planning artifacts
```

## Commits (since baseline `5429c01`)
```
(none — all changes are in the working tree and will land in this wrapup commit)
```

---
*Generated by `/forge:wrapup`. Load the latest wrapup with `/forge:resume`.*
