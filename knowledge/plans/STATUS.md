# STATUS — Steroids gem progress

**Last updated:** 2026-06-03
**Current branch:** develop
**Current focus:** documentation accuracy + knowledge-base sync (post RSpec migration)

---

## Recent wins (chronological)

| Date | Wrapup | Headline |
|------|--------|----------|
| 2026-05-11 | [[wrapups/@2026-05-11-01-error-reportability-observability-seam]] | Introduced `Steroids::ErrorReporter` + opt-out class attribute. Fixed unregistered-error-class status fallback. Added `flash_key`. |
| 2026-05-13 | [[wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite]] | Removed `async_process` + `Sidekiq.server?` heuristic. New `.call` / `.call_sync` / `.call_async` API. Per-mode `success_notice`. Call-site serializability validation. |
| 2026-06-03 | (no wrapup yet) | Migrated suite Minitest → RSpec (`spec/`). Added per-class `wrap_in_transaction false` opt-out. Rewrote `README.md` as a single comprehensive API tour. Scrubbed a consumer-name leak from a doc comment. |

## Capability completion

| Capability | % | Notes |
|------------|---|-------|
| Service objects (lifecycle, callbacks, transactions, drop!) | 100% | + per-class `wrap_in_transaction false` opt-out (2026-06-03) |
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
| **Test coverage expansion** | 100% | extensions, logger, types |
| **RSpec migration** | 100% | Minitest → RSpec, `test/` → `spec/` (2026-06-03) |
| **Documentation (README)** | 100% | Comprehensive single-file API tour (2026-06-03) |

## Test suite snapshot

After the 2026-06-03 RSpec migration:

- **Framework:** RSpec (`rspec` ~> 3.13, `rspec-rails` ~> 7.1) — replaced Minitest
- **Examples:** 220 passing / 0 failing (`bundle exec rspec`, verified 2026-06-03)
- **Spec files:** 27 `*_spec.rb` under `spec/` (+ `spec_helper.rb`), mirroring `lib/`
- **Rubocop:** 0 offenses (clean baseline via `.rubocop_todo.yml`)
- **Coverage tool:** `simplecov` is now in the `Gemfile` (test group) but not yet wired into `spec_helper.rb` — enabling it is a remaining backlog item

## Engagement log (2026-06-03)

1. ✅ Rewrote `README.md` as a single comprehensive API tour — corrected several stale claims carried by the old docs (Ruby 3.3 / Rails 7, RSpec not Minitest, the real `wrap_in_transaction false` macro, block-less `.call` **raises** on failure, no `async:` control flag, `force`/`skip_callbacks` work as documented). Added per-section dos & don'ts.
2. ✅ Scrubbed a consumer-name leak from a doc comment in `lib/steroids/support/servicable_methods.rb` (guideline X1 — zero tolerance for public packages).
3. ✅ Knowledge-base refresh (`/forge:refresh`): reconciled MASTER/STATUS/INDEX to the RSpec + per-class-transaction reality, updated living `ar-*` / `biz-*` docs (test paths `test/` → `spec/`, transaction opt-out), fixed an X2 violation (committed KB file naming the machine-local shared base), added two project guidelines.

## Engagement log (2026-05-13)

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

The six pre-existing service-call-contract errors tracked through the 2026-05-11 and 2026-05-13 (Minitest-era) wrapups are **no longer present** — the RSpec suite reports 220 passing / 0 failing. The migration settled the call contract those errors hinged on (block-less `.call` raises `NoticableMethods::RuntimeException` on failure; the block form captures). No carried-forward failures remain.

## Pointers

- Master spec: [[MASTER]]
- Knowledge index: [[INDEX]]
- Streaming progress design: [[plans/@2026-05-13-01-streaming-progress-notices]]
