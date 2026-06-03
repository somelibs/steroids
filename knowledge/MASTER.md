# MASTER — Steroids gem product spec

**Version:** 1.6.1 (current) | **Status:** mature, evolving | **License:** MIT
**Last refreshed:** 2026-06-03

## Product statement

A Rails enhancement gem that ships opinionated abstractions for the patterns Rails apps reach for daily — service objects with predictable lifecycle, a non-AR errors layer, caller-decides async dispatch, an APM-agnostic error-reporting seam, a typed-attribute system, and a small constellation of Ruby core extensions.

Not a framework. Not a kitchen-sink. A focused toolkit for teams that already know the patterns and want them codified.

## Target users

Rails developers (Ruby 3.3+, Rails 7+) who have been burned by:

- Service objects that disagree on lifecycle (some return tuples, some raise, some swallow).
- `ActiveRecord::Errors` being attribute-keyed when their service spans multiple records.
- `Sidekiq.server?` heuristics that silently run inline in some environments and async in others.
- APM coupling — wanting to swap AppSignal/Sentry/Honeybadger without rewiring every rescue block.

## Capability inventory

Full feature list lives in [[biz-features]]. Roll-up:

| Capability | Status | Owner module |
|------------|--------|--------------|
| Service base class (lifecycle, drop!, callbacks, transactions) | ✅ shipped | `Steroids::Services::Base` |
| Per-class transaction opt-out (`wrap_in_transaction false`) | ✅ shipped (Jun 2026) | `Steroids::Services::Base.wrap_in_transaction` |
| Per-call async dispatch (`.call` / `.call_sync` / `.call_async`) | ✅ shipped (May 2026) | `Steroids::Services::Base`, `Steroids::AsyncServiceJob` |
| `async_only!` marker | ✅ shipped | `Steroids::Services::Base.async_only!` |
| Call-site serializability validation with dotted-path errors | ✅ shipped | `Steroids::Services::Base.validate_serializable!` |
| Per-mode (sync/async) `success_notice` resolution | ✅ shipped | `NoticableMethods::NoticableRuntime` |
| Errors/notices layer (Noticable) | ✅ shipped | `Steroids::Support::NoticableMethods` |
| Controller `service` macro | ✅ shipped | `Steroids::Support::ServicableMethods` |
| `respond_with` JSON renderer | ✅ shipped | `Steroids::Controllers::RespondersHelper` |
| Error class hierarchy (HTTP statuses) | ✅ shipped | `Steroids::Errors::*` |
| Agnostic error reporter (`Rails.error.report` seam) | ✅ shipped (May 2026) | `Steroids::ErrorReporter` |
| `report_to_observability` opt-out | ✅ shipped | `Steroids::Errors::Base.class_attribute` |
| Colorized logger | ✅ shipped | `Steroids::Logger` (rainbow) |
| Typed attributes (`Steroids::Types::Base`) | ✅ shipped | `Steroids::Types::*` |
| ActiveModel::Serializer wrapper | ✅ shipped | `Steroids::Serializers::Base` + `Methods` |
| Ruby core extensions | ✅ shipped | `Steroids::Extensions::*` |
| RSpec test suite (migrated from Minitest) | ✅ shipped (Jun 2026) | `spec/` (220 examples, 0 failures) |
| Rubocop config (`.rubocop.yml` + baseline) | ✅ shipped | `.rubocop.yml`, `.rubocop_todo.yml` |
| Comprehensive single-file README (full API tour, dos & don'ts) | ✅ shipped (Jun 2026) | `README.md` |
| Streaming `progress(message)` mid-execution notices | 🟡 design only | plan: [[plans/@2026-05-13-01-streaming-progress-notices]] |

## Architecture summary

See [[ar-overview]]. Three things to know:

1. **Engine + Railtie + Zeitwerk + explicit `load_extensions!`.** Core extensions are required eagerly so Ruby class monkey-patches are visible to host-app code before it boots.
2. **Single `def process` per service.** Async-ness is decided at the call site. The old `async_process` + `Sidekiq.server?` heuristic was removed in May 2026 — see [[wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite]].
3. **Observability is delegated.** Steroids forwards handled exceptions through `Rails.error.report` and stops. The host app (or its APM gem) subscribes. See [[wrapups/@2026-05-11-01-error-reportability-observability-seam]] and [[ar-errors-observability]].

## Roadmap

### Recently shipped (Jun 2026)

- ✅ **RSpec migration** — the suite moved from Minitest (`test/`) to RSpec (`spec/`), 220 examples / 0 failures; `rspec`/`rspec-rails`/`simplecov` added as dev gems.
- ✅ **Per-class transaction opt-out** — `wrap_in_transaction false` macro (resolves the old `@@wrap_in_transaction` per-service backlog item).
- ✅ **Documentation overhaul** — `README.md` rewritten as a single comprehensive, accurate API tour (services, noticable, controllers, async, errors, logger, extensions, types) with dos & don'ts per section.
- ✅ **Linting + test coverage** — `.rubocop.yml` baseline (0 offenses) and expanded unit coverage (extensions, logger, types).

### Next

- **Streaming progress notices** — see [[plans/@2026-05-13-01-streaming-progress-notices]]. Adds `progress(message, **tags)` to services with a pluggable publisher (default no-op, ActionCable adapter, Test adapter). Composes orthogonally with the per-call dispatch + Hash `success_notice` work.

### Backlog (no concrete plan yet)

- Decide whether `MagicClass#inherited` ivar propagation (TODO in code) should land.
- Wire `simplecov` into the spec run (gem is in the `Gemfile`; coverage report not yet enabled in `spec_helper.rb`).
- Replace the `OTPIONS` typo in `Steroids::Errors::Base` with `OPTIONS` (mild — public surface is unaffected).
- Modernize `Steroids::Controllers::Methods#context` (marked deprecated in code comments).

## Acceptance criteria for future work

Any new capability MUST:

1. Work identically through sync and async dispatch where applicable (don't reintroduce per-class async coupling).
2. Default to a no-op when its dependency isn't present in the host app (mirror the `Rails.error.report` graceful-degrade pattern in `Steroids::ErrorReporter`).
3. Ship with **RSpec** specs (under `spec/`, mirroring `lib/`) using the ActiveJob `:test` adapter convention for async work.
4. Update `CHANGELOG.md` `[Unreleased]` with migration notes if behavior changes.
5. Be reflected in the knowledge base (this index, the relevant `ar-*` doc).

## References

- README.md — user-facing usage (full API tour)
- AGENTS.md / CLAUDE.md — agent-targeted guidance (overlaps with README; both kept in sync per current convention)
- CHANGELOG.md — release notes (Keep a Changelog)
- knowledge/INDEX.md — file-level index
- knowledge/plans/STATUS.md — progress tracking
- knowledge/wrapups/ — point-in-time engagement records
