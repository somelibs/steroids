# Wrapup: RSpec migration, transaction-wrap hardening & docs sync

**Date:** 2026-06-13
**Branch:** develop
**Baseline:** previous wrapup `@2026-05-13-01-per-call-async-dispatch-rewrite.md` (recorded HEAD `5429c01`)
**HEAD at wrapup:** e703081b20a6b7983fc6d3166d94f8fa44c5d462
**Note:** —

---

## Summary
Three coherent pieces of work since the last wrapup: (1) the test suite migrated wholesale from Minitest to RSpec — `test/` deleted, `spec/` mirrors `lib/`, 220 examples / 0 failures (the six pre-existing service-call-contract errors from the Minitest era are gone); (2) the automatic `ActiveRecord::Base.transaction` wrap gained a per-class opt-out and then had its underlying `@@wrap_in_transaction` shared class variable removed entirely as a footgun; (3) the README and knowledge base were rewritten to match the current implementation, and two project guidelines (S1, S2) were codified. The first two pieces landed in commits `3557cca` and `e703081`; the class-variable removal and the AGENTS.md guidelines-load section are the uncommitted batch this wrapup commits.

## What We Did
- **RSpec migration** (`3557cca`) — Replaced `test/` (Minitest) with `spec/` (RSpec 3.13 + rspec-rails 7.1; SimpleCov optional via `COVERAGE=1`). 220 examples pass; line coverage 85.3% / branch 74.7%. Rakefile default task switched to `:spec`. `.rubocop.yml` scopes line-length, class-var, and number-naming cops out of `spec/`. Migrated assertions caught up with the per-call async dispatch rewrite — block-less `.call` now raises `NoticableMethods::RuntimeException` when errors accumulate.
- **Per-class transaction opt-out** (`3557cca`) — Added the `wrap_in_transaction false` class macro backed by the `wrap_in_transaction_override` `class_attribute`, for services that primarily hit a 3rd-party API and shouldn't hold a DB connection across remote latency.
- **`@@wrap_in_transaction` footgun removal** (uncommitted) — `lib/steroids/services/base.rb`: removed the `@@wrap_in_transaction` shared class variable. Assigning it in a subclass wrote the *ancestor's* variable, so one service's opt-out silently disabled the transaction wrap for every sibling in the host app. `wrap_in_transaction?` now returns `override.nil? || override` (default on), with the per-class `class_attribute` as the only switch. Added a regression spec (`spec/steroids/services/base_spec.rb`) asserting a stray `@@wrap_in_transaction` assignment is inert and the class variable is undefined; updated `spec/steroids/services/lifecycle_spec.rb`'s `around` hook to toggle `wrap_in_transaction_override` instead of the removed class variable.
- **README + knowledge base rewrite** (`e703081`) — README rewritten as a single comprehensive API tour with per-section dos & don'ts; corrected stale claims (RSpec not Minitest, Ruby 3.3 / Rails 7, the real `wrap_in_transaction` macro, block-less `.call` raises, no `async:` control flag). Reconciled MASTER/STATUS/INDEX and the `ar-*` / `biz-*` living docs to the RSpec migration + transaction opt-out. Added project guidelines S1 (compact error-raise form) and S2 (string-only noticable messages); removed a consumer-name leak from a doc comment.
- **AGENTS.md guidelines-load section** (uncommitted) — Added the mandatory "load before any work" guidelines block rendering S1/S2 inline (K6 compliance).
- **CHANGELOG** (this wrapup) — Corrected the stale "global `@@wrap_in_transaction` default still applies" sentence and added a `Removed — @@wrap_in_transaction shared class variable` entry under `[Unreleased]`.

## Current Status
- Test suite green on RSpec: **220 examples, 0 failures**. RuboCop clean on changed files.
- Transaction-wrap behavior is now leak-proof: per-class `class_attribute`, default-on, no shared mutable class state.
- README and knowledge base are in sync with the current implementation (RSpec, per-call async, transaction opt-out).
- No plan reached a terminal state this batch — the only open plan (`@2026-05-13-01-streaming-progress-notices`, status Draft) is unrelated and untouched.

## Open Issues / Risks
- None. The previously tracked six service-call-contract errors are resolved by the RSpec migration.

## Pending / Cleanup
- [ ] Streaming progress notices (`@2026-05-13-01-streaming-progress-notices.md`) remains a Draft plan, not started.

## Next Steps
1. Consider whether the streaming-progress-notices plan is next on the roadmap, or shelve it explicitly.
2. Optional: raise branch coverage (74.7%) toward the line-coverage figure if coverage gates are desired in CI.

## Notes & Decisions
- The transaction-wrap default deliberately moved from a `@@class_variable` to "implicit in `wrap_in_transaction?`" rather than a second `class_attribute` default — `override.nil? || override` keeps a single source of truth (the override) and removes any shared mutable state that a subclass could clobber.
- `.rubocop.yml` intentionally scopes class-var / number-naming / line-length cops out of `spec/` so test fixtures read naturally.

## Lint & Test Status
- RuboCop (changed files): ✅ 3 files, no offenses
- RSpec: ✅ 220 examples, 0 failures

---

## Changed Files (since baseline)
```
 lib/steroids/services/base.rb                      |   ~20 (transaction wrap)
 spec/** (new RSpec suite)                          | +1900
 test/** (removed Minitest suite)                   | -1707
 README.md, knowledge/**, AGENTS.md, CHANGELOG.md   | docs sync + guidelines
 87 files changed, 5840 insertions(+), 2528 deletions(-)
```

## Commits (since baseline)
```
e703081 Rewrite README and sync knowledge base to current implementation
3557cca Migrates test suite from Minitest to RSpec and adds per-class transaction opt-out
(+ uncommitted: @@wrap_in_transaction removal, AGENTS.md guidelines block, CHANGELOG)
```

---
*Generated by `/forge:wrapup`. Load the latest wrapup with `/forge:resume`.*
