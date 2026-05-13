# STATUS — Steroids gem progress

**Last updated:** 2026-05-13
**Current branch:** develop (clean at session start)
**Current focus:** post-wrapup cleanup + linting + test coverage

---

## Recent wins (chronological)

| Date | Wrapup | Headline |
|------|--------|----------|
| 2026-05-11 | [[wrapups/@2026-05-11-01-error-reportability-observability-seam]] | Introduced `Steroids::ErrorReporter` + opt-out class attribute. Fixed unregistered-error-class status fallback. Added `flash_key`. |
| 2026-05-13 | [[wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite]] | Removed `async_process` + `Sidekiq.server?` heuristic. New `.call` / `.call_sync` / `.call_async` API. Per-mode `success_notice`. Call-site serializability validation. |

## Capability completion

| Capability | % | Notes |
|------------|---|-------|
| Service objects (lifecycle, callbacks, transactions, drop!) | 100% | Stable since pre-1.0 |
| Per-call async dispatch | 100% | Landed 2026-05-13 |
| Noticable layer (errors/notices/notice/flash_key) | 100% | + per-mode resolution (2026-05-13) |
| Controller `service` macro (sync + async) | 100% | + async preview-instance block (2026-05-13) |
| Agnostic error reporter | 100% | Landed 2026-05-11 |
| Error classes (HTTP) | 100% | Stable |
| Ruby core extensions | 100% | + `Method#apply` bug fix (2026-05-13) |
| Types system | 100% | + test coverage (2026-05-13) |
| Serializers (AMS wrapper) | 100% | Pending upstream PRs |
| Logger | 100% | + notifier/backtrace bug fixes (2026-05-13) |
| Streaming progress notices | 0% | Design doc only — see plan |
| **Rubocop config** | 100% | Landed 2026-05-13 — clean baseline via `.rubocop_todo.yml` |
| **Test coverage expansion** | 100% | +76 runs / +131 assertions (extensions, logger, types) |

## Test suite snapshot

After 2026-05-13 engagement:

- **Runs:** 178 (up from 102)
- **Assertions:** 373 (up from 242)
- **Failures:** 0
- **Errors:** 6 (all pre-existing service-call-contract errors — same 6 documented since the 2026-05-11 wrapup; out of scope until explicitly addressed)
- **Rubocop:** 0 offenses (clean baseline via `.rubocop_todo.yml`)
- **Coverage tool:** still not wired up (e.g. simplecov) — punted to future engagement

## Engagement log (this session, 2026-05-13)

1. ✅ Forge knowledge base scaffold + INDEX + MASTER + STATUS + GUIDELINES
2. ✅ Cleanup wrapup todos:
   - `test/services/async_service_test.rb:273–281` — alias_method trampoline → `ConstructorSpyService` fixture
   - `test/services/async_service_test.rb:299–306` — `class_eval` setup swap → `CallbackCounterService` fixture
   - `test/errors/error_serializer_test.rb:10,13` — `silence_warnings` wrap (no more "method redefined" output)
   - `lib/steroids/services/base.rb` — audited; no `before_process` callbacks in repo used the dropped `*args, **options` signature; `send_apply` arity-matches so even host-app callbacks declared that way would degrade gracefully
3. ✅ `.rubocop.yml` + `.rubocop_todo.yml` + dev gems (`rubocop`, `rubocop-rails`)
4. ✅ Test coverage expansion — extensions (object/array/hash/method/class/module), logger, types
5. ✅ Surfaced + fixed 4 real bugs while writing the new tests:
   - `Method#apply` — `yield` → `call` (Method has no `yield`)
   - `Logger#print` — pass `@exception`, not formatted output, to `notify`
   - `Logger#notify` — read class-level notifier (`self.class.notifier`), not instance ivar
   - `Logger#format_backtrace` — `@backtrace&.any?` (was nil-crashing on never-raised exceptions)

## Open issues from prior wrapups

Six pre-existing service-call-contract test errors carried forward from the 2026-05-11 wrapup, unchanged in the 2026-05-13 wrapup. Out of scope for this engagement unless explicitly raised — see the 2026-05-13 wrapup file for the list.

## Pointers

- Master spec: [[MASTER]]
- Knowledge index: [[INDEX]]
- Streaming progress design: [[plans/@2026-05-13-01-streaming-progress-notices]]
