# Template Project TODOs

## Architecture Sync

Ordered by priority, next task first. Each is scoped to one focused pull
request. Validate Swift changes with `mise exec -- tuist generate --no-open`
followed by `mise exec -- tuist test AllTests --platform macos --no-selective-testing`
(the generated project has multi-platform targets, so never run `tuist build`
without `--platform`); do not rely on a simulator run.

- [x] Declare the feature test-bundle dependencies and gate them in CI (Tasker #521)
  `mise exec -- tuist inspect dependencies` fails on main: NoteEditorFeatureTests
  implicitly depends on ComposableArchitecture and Core; NotesListFeatureTests on
  ComposableArchitecture, Core and NoteEditorFeature. Add `testDependencies`
  (Core + `.indigoFoundation`, plus NoteEditorFeature for NotesListFeature) to
  their `Project.swift`, matching `AuthFeature/Project.swift`. Replace the
  deprecated `tuist inspect implicit-imports` / `redundant-imports` commands with
  `mise exec -- tuist inspect dependencies` in AGENTS.md, README.md and
  `.agents/skills/tuist-inspect/SKILL.md`, and add that command as a step after
  `Generate project` in `.github/workflows/tests.yml`.
  Acceptance: `tuist inspect dependencies` exits 0; no doc references the
  deprecated commands; the macOS `AllTests` run passes.
- [ ] Correct docs/local-caching.md and the AGENTS.md persistence convention against the shipped code (Tasker #522)
  AGENTS.md says reads use `@FetchAll`, but the shipped example reads through
  `NotesClient` and refetches after writes. docs/local-caching.md declares a
  custom `DefaultDatabaseKey` (SQLiteData already provides `defaultDatabase`),
  shows an `AppMigrations.register(in:)` enum (shipped: `DatabaseMigrator.baseMigrator`
  + `registerV1Migration()`), says tests use a `DatabaseQueue` (shipped: a
  `DatabasePool` at a temporary path), and pins sqlite-data `1.4.0` (shipped:
  1.12.0). Docs only: align those sections with `Core/Sources/Database` and keep
  `@FetchAll` marked as an alternative the example does not use.
  Acceptance: `grep -r "AppMigrations\|DefaultDatabaseKey" docs/` returns nothing;
  AGENTS.md no longer implies the example uses `@FetchAll`.

## Not ready

- Tasker #37 — blocked: Move from Tuist to new Xcode format
- Tasker #523 — paused: Proposal: In-app account deletion from AccountFeature
- Tasker #524 — paused: Proposal: Ship a String Catalog for user-facing strings

## Completed

Shipped and merged; kept as a short record so the work is not re-proposed.

- [x] Upgrade the Swift toolchain and dependency graph
- [x] Declare `DependenciesMacros` in `.indigoFoundation`
- [x] Align `JSONCoders.api` with the JSON the template actually exchanges
- [x] Build the token-refresh request with `HTTPRequestBuilder`
- [x] Add `APIErrorBody` for reading 4xx response bodies
- [x] Rewrite `docs/api-clients.md` against the shipped code
- [x] Standardize runnable commands on `mise exec -- tuist`
- [x] Make the `Sharing` → `SwiftSharing` module alias usable by `Core`
- [x] Wire the DEBUG network console to the existing shake modifier
- [x] Bootstrap the stored auth session at the app root
- [x] Give the `App` target the `Sharing` module alias
- [x] Put the shared network session behind a `Core` dependency
- [x] Correct the authentication section of `docs/api-clients.md`
- [x] Lift the launch gate before the background token refresh
- [x] Ship the `apiClient` dependency alias in `Core`
- [x] Extend `usesSharing` to the generated test targets
- [x] Wipe the user-scoped cache when the auth session changes
- [x] Ship a sign-out seam that revokes the refresh token before ending the session
- [x] Let the sandboxed macOS app open outgoing network connections
- [x] Give `SessionClient` a sign-in operation that stores the issued tokens
- [x] Map the version build settings into the app's `Info.plist`
- [x] Send an explicit JSON content type on the sign-in request
- [x] Keep Xcode Cloud output alive while `tuist generate` runs
- [x] Point DEBUG builds at the local backend dev server
- [x] Bump the Tuist pin to 4.208.0
- [x] Ship an app privacy manifest
- [x] Move the cache database into Application Support and split it by configuration
- [x] Adopt Xcode's recommended build settings in the App xcconfigs
- [x] Put the sign-out gate in the documented refresh wiring
- [x] Give `SessionClient` sign-up and password-reset request operations
- [x] Drop the `xctest-dynamic-overlay` pin from `Package.swift`
- [x] Give `SessionClient` verification-email and password-reset operations
- [x] Add an `AuthFeature` module with sign-in and sign-up forms
- [x] Present `AuthFeature` from `RootFeature` and ship a sign-out control
- [x] Add a forgot-password sheet to `AuthFeature`
- [x] Cancel the in-flight notes fetch when the user cache is wiped
- [x] Offer a verification-email resend when sign-in is refused as unverified
- [x] Ship an `AccountClient` that fetches the signed-in profile
- [x] Add an `AccountFeature` module that shows the signed-in profile
- [x] Present `AccountFeature` from `RootFeature` for signed-in users
- [x] Adopt HTTPTransport and ship Pulse in Debug builds only
- [x] Adopt Xcode 27.2 recommended project settings
- [x] Decouple Pulse from http-request-client and jwt-auth-client (Tasker #405)
- [x] Adopt the Pulse-free http-request-client and jwt-auth-client in indigo-swiftui (Tasker #406)
- [x] Make logging-client Pulse-free (PulseLogHandler as an optional Debug layer) (Tasker #407)
