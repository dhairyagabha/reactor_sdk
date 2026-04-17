## [1.0.0] - 2026-04-17

- Changed `Libraries#find_snapshot` to return the effective inherited Launch snapshot for the target library instead of only the records directly attached to that library.
- Added `Libraries#find_direct_snapshot` for callers that still need the previous direct-only snapshot behavior.
- Corrected library comparison and review payloads so upstream resources inherited unchanged into the current library are reported as `unchanged` instead of `removed`.
- Hardened `Libraries#find_with_resources` so it can parse symbolized response hashes and fall back to related library resource endpoints when Adobe omits the `included` payload.
- Enforced `auto_refresh_token: false` during authentication. The initial token is still fetched, but expired cached tokens now raise `AuthenticationError` instead of silently refreshing.
- Added migration guidance in the README and documentation for the snapshot and authentication changes introduced in `1.0.0`.

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
