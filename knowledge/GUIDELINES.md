# Project Guidelines

**Last Updated:** 2026-06-03
**Total Guidelines:** 2
**Enforced In:** CLAUDE.md (alias AGENTS.md), MASTER.md, INDEX.md

---

## Active Guidelines

### 🧱 Steroids API conventions

| # | Guideline | Added | Source |
|---|-----------|-------|--------|
| S1 | **Raise Steroids errors with the compact form** — `raise SomeError.new(message: "...", status: ..., log: true)`. Steroids errors (`Steroids::Errors::Base` and subclasses, including the internal `drop!` `RuntimeError`) consume keyword options (`:message`, `:status`, `:errors`, `:code`, `:cause`, `:context`, `:log`). The exploded form `raise SomeError, message: "..."` silently **drops** those kwargs, and a rubocop `Style/RaiseArgs` autocorrect to that form has crashed `drop!` with a `TypeError` before. `.rubocop.yml` pins `Style/RaiseArgs` to `compact` and disables `Style/RedundantException` on `drop!` to defend this. See [[ar-services]], [[ar-errors-observability]]. | 2026-06-03 | `lib/steroids/services/base.rb` `drop!` comment; `.rubocop.yml` |
| S2 | **Noticable messages are Strings, never AR-style attribute keys** — use `errors.add("Human message")` / `errors.add("Human message", exception)` / `notices.add("Human message")`. The first argument is `typed!(String)`, so the ActiveRecord idioms `errors.add(:base, "...")` or `errors.add(:field, "...")` raise `TypeError`. Messages may surface verbatim in a flash or API payload, so write full sentences. See [[ar-noticable]]. | 2026-06-03 | `lib/steroids/support/noticable_methods.rb` `NoticableCollection#add` |

---

## Enforcement Points

Guidelines are enforced at these touchpoints:

| Touchpoint | How |
|------------|-----|
| **CLAUDE.md / AGENTS.md** | Listed in the API-tour error-handling section |
| **MASTER.md** | Referenced in acceptance criteria |
| **INDEX.md** | Cross-referenced for discoverability |
| **`.rubocop.yml`** | S1 is enforced mechanically (`Style/RaiseArgs: compact`) |

Project-specific guidelines extend the project-agnostic baseline maintained outside this repository. Both apply; project-specific guidelines take precedence on conflict.

---

## Retired Guidelines

_None._
