# Knowledge Index

**Last refreshed:** 2026-06-03
**Project:** Steroids — Rails enhancement gem (v1.6.1)
**Knowledge base:** 11 files (this index excluded)

---

## Business

| File | Purpose |
|------|---------|
| [biz-overview.md](biz-overview.md) | What Steroids is, who uses it, distribution, dependencies |
| [biz-features.md](biz-features.md) | Flat catalog of every shipped capability |

## Architecture

| File | Purpose |
|------|---------|
| [ar-overview.md](ar-overview.md) | Boot sequence, directory layout, inheritance chains, hot paths |
| [ar-services.md](ar-services.md) | `Steroids::Services::Base` lifecycle, drop!, callbacks, blocks, transactions |
| [ar-async-dispatch.md](ar-async-dispatch.md) | Per-call `.call` / `.call_sync` / `.call_async`; `AsyncServiceJob`; serializability validation |
| [ar-noticable.md](ar-noticable.md) | `NoticableCollection`, `NoticableRuntime`, success_notice resolution table |
| [ar-errors-observability.md](ar-errors-observability.md) | Error hierarchy, `Steroids::ErrorReporter` agnostic seam, auto-report wiring |
| [ar-controllers.md](ar-controllers.md) | `Controllers::Methods`, `service` macro, `respond_with` JSON renderer |
| [ar-extensions.md](ar-extensions.md) | Ruby core monkey-patches (Object/Hash/Array/Method/Proc/Class/Module) |
| [ar-types-serializers.md](ar-types-serializers.md) | `Types::SerializableType` + `Types::Base`; AMS-based `Serializers::Base` |

## Plans

| File | Status |
|------|--------|
| [MASTER.md](MASTER.md) | Living PRD, feature inventory, roadmap |
| [plans/STATUS.md](plans/STATUS.md) | Progress tracking, current focus |
| [plans/@2026-05-13-01-streaming-progress-notices.md](plans/@2026-05-13-01-streaming-progress-notices.md) | Forward-looking: in-band progress messages |

## Wrapups

| File | Date | Headline |
|------|------|----------|
| [wrapups/@2026-05-11-01-error-reportability-observability-seam.md](wrapups/@2026-05-11-01-error-reportability-observability-seam.md) | 2026-05-11 | Introduced `Steroids::ErrorReporter`, observability seam, `flash_key`, opt-out class attr |
| [wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite.md](wrapups/@2026-05-13-01-per-call-async-dispatch-rewrite.md) | 2026-05-13 | Rewrote async dispatch end-to-end (`.call` / `.call_async`, Hash `success_notice`, `control:`) |

## Guidelines

| File | Purpose |
|------|---------|
| [GUIDELINES.md](GUIDELINES.md) | Project-specific development guidelines (2 active: compact error-raise form, string-only noticable messages) |

---

## Pattern counts

| Pattern | Count |
|---------|-------|
| Architecture documents (ar-*) | 8 |
| Business documents (biz-*) | 2 |
| Active plans | 1 |
| Wrapups | 2 |
| Active guidelines | 2 |

## Cross-reference graph

```
biz-overview  →  ar-overview, ar-services, ar-noticable, ar-async-dispatch,
                 ar-errors-observability, ar-extensions, ar-types-serializers

ar-overview   →  ar-services, ar-async-dispatch, ar-errors-observability

ar-services   →  ar-async-dispatch, ar-extensions, ar-errors-observability,
                 ar-noticable

ar-async-dispatch → ar-services, ar-noticable, ar-errors-observability,
                    wrapups/@2026-05-13-01

ar-noticable      → ar-services, ar-extensions

ar-errors-observability → ar-services, ar-types-serializers,
                          wrapups/@2026-05-11-01

ar-controllers   → ar-services, ar-async-dispatch, ar-noticable

ar-extensions    → (leaf)

ar-types-serializers → ar-noticable, ar-errors-observability

GUIDELINES       → ar-services, ar-errors-observability, ar-noticable
```

## Conventions

- **`ar-*`** — architecture deep-dives, one per subsystem. **`biz-*`** — what/who/why.
- **Living docs** (everything except `wrapups/`) track current behavior and are refreshed by `/forge:refresh`.
- **`wrapups/@*.md`** are point-in-time engagement records — historical, never rewritten.
- Reusable Ruby/Rails best practices and baseline guidelines are maintained outside this repository and copied in (genericized) when needed — never linked out to, so in-repo references stay resolvable for every contributor.
