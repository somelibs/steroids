# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Steroids::ErrorReporter` — agnostic seam that forwards *handled* exceptions through `Rails.error.report` (and on to whatever observability subscriber the parent app registered). Idempotent per exception, no-ops when `Rails.error` is unavailable, and never raises.
- `Steroids::Services::Base#report_error!` (alias `report_to_observability!`) — called automatically for every rescued `StandardError` in a service; subclasses can also call it from their own rescue blocks. Accepts context tags forwarded to the reporter.
- `Steroids::Errors::Base.report_to_observability` class attribute (default `true`) — set to `false` on "expected" error subclasses (validation, flow control) to keep them out of observability dashboards.
- `Steroids::Support::NoticableMethods` — `flash_key` (`:alert` when there are errors, otherwise `:notice`), also delegated to the includer and passed to service block callbacks as `flash_key:`.

### Changed
- `Steroids::Services::Base#async_exec?` — outside `development`/`test`, async services are now always enqueued without probing Sidekiq, so a briefly unreachable Redis raises on enqueue instead of silently running the service inline in the request thread. In `development`/`test`, behaviour is unchanged (enqueue only when a worker is registered).
- `Steroids::ErrorSerializer` — the `exception` attribute is still dev-only; the redundant duplicate `message` declaration in the dev-only block was removed (`message` is already serialized unconditionally).

### Fixed
- Unregistered `Steroids::Errors::Base` subclasses now fall back to their own `default_status` instead of always resolving to `:internal_server_error`. `ActionDispatch::ExceptionWrapper.rescue_responses` is a Hash with a default value, which previously short-circuited the status resolution for any error class the consuming app had not manually registered.
- README: `bundle config local.steroids …` / `bundle config disable_local_branch_check …` updated to the `bundle config set …` form.
