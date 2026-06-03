# biz-overview — Steroids gem

**Type:** Rails enhancement library (Ruby gem, distributed via RubyGems).
**Current version:** `1.6.1` (see `lib/steroids/version.rb`).
**License:** MIT.
**Required Ruby:** `>= 3.3`. **Required Rails:** `>= 7` (Gemfile pins `~> 7.1`).
**Author:** Paul Reboh (`paul@reboh.net`).
**Repo:** https://github.com/somelibs/steroids.

## Why it exists

Steroids opinionates the patterns a Rails application uses most:

1. **Service objects** with predictable lifecycle (callbacks, transactions, error capture, flow control) — see [[ar-services]].
2. **A non-ActiveRecord errors/notices layer** (`NoticableMethods`) that decouples user-facing messaging from validation errors — see [[ar-noticable]].
3. **Caller-decides async dispatch** — every service has one `def process`; `.call` / `.call_sync` runs inline, `.call_async` enqueues an `ActiveJob`. No `Sidekiq.server?` heuristic. See [[ar-async-dispatch]].
4. **An agnostic error-reportability seam** (`Steroids::ErrorReporter`) that forwards handled exceptions through `Rails.error.report` to whatever APM the host app wires up — see [[ar-errors-observability]].
5. **Ruby core extensions** (Object, Hash, Array, Method/Proc, Module, Class) that the rest of the gem and host apps rely on — see [[ar-extensions]].
6. **An ActiveModel-flavored type & serializer toolkit** — see [[ar-types-serializers]].

## Who uses it

A small handful of Rails apps within the author's orbit. It is **not** a general-purpose gem yet — the docs and README assume a reader who already knows the patterns.

## Distribution

- Built as a gemspec (`steroids.gemspec`), published to RubyGems under the `allowed_push_host = https://rubygems.org` policy.
- A `steroids-1.6.1.gem` artifact lives at the repo root.
- Gem files cover `app/`, `config/`, `misc/`, `db/`, `lib/` plus `Rakefile` and `README.md`.

## Runtime dependencies

| Gem | Constraint | Why |
|-----|-----------|-----|
| `rails` | `>= 7` | Engine, Railtie, ActiveJob, ActiveModel, ActiveRecord |
| `rainbow` | `>= 3.1` | Colorized logger output (`Steroids::Logger`) |

Dev/test only: `active_model_serializers ~> 0.10.14`, `sqlite3 ~> 1.4`.

## Adjacent docs

- Root `CLAUDE.md` (== `AGENTS.md`) — agent guidance and per-feature usage examples.
- Root `README.md` — user-facing introduction and full API tour.
- Root `CHANGELOG.md` — release notes (Keep a Changelog format).
- Forge knowledge: [[ar-overview]], [[MASTER]], [[plans/STATUS]].
