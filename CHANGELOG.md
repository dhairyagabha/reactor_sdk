## [0.1.0] - 2026-04-01

- Added support for app configurations, callbacks, secrets, extension packages,
  extension package usage authorizations, profile lookup, search, and direct
  note lookup to align the SDK with Adobe's current Reactor endpoint families.
- Added missing relationship and maintenance operations across properties,
  extensions, libraries, builds, rules, rule components, and notes-bearing
  resources.
- Corrected audit event listing to use Adobe's current global `/audit_events`
  endpoint while keeping `list_for_property` as a backward-compatible wrapper.
- Added multipart extension package upload support and coverage for the new
  endpoint surface.
- Added contributor and security documentation for open source maintenance.
- Added a pinned `.ruby-version` to align local development with CI.
- Expanded CI and core infrastructure test coverage.
- Aligned gem metadata and install documentation with the published gem name.
- Documented current Adobe Reactor API coverage and multi-client usage patterns.
- Added test coverage proving separate client instances keep credentials isolated.
- Initial public release.
