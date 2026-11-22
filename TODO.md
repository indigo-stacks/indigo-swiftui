# Template Project TODOs

## Architecture Sync

Ordered by priority, next task first. Each is scoped to one focused pull
request. Validate Swift changes with `mise exec -- tuist generate --no-open`
followed by `mise exec -- tuist test AllTests --platform macos --no-selective-testing`
(the generated project has multi-platform targets, so never run `tuist build`
without `--platform`); do not rely on a simulator run.

- [x] Chain keyboard focus and Return-to-submit through the auth forms (Tasker #540)
  `AuthView` and `ForgotPasswordView` have no `@FocusState`: Return does not
  move to the next field or submit. Add a focus enum (name, email, password)
  with `.submitLabel(.next)` / `.onSubmit` moving focus forward, and
  `.submitLabel(.go)` / `.onSubmit { store.send(.submitButtonTapped) }` on the
  last field of both forms. Give the loading `ProgressView` in each submit
  button an accessibility label. The reducers already guard submit, so no
  reducer change.
  Acceptance: Return on the last field submits both forms; the macOS
  `AllTests` run passes.
- [ ] Document RootFeature, AuthFeature and AccountFeature in the README and AGENTS.md module layout (Tasker #541)
  README "Project Architecture" lists only the notes features, and its graph
  shows App depending on them directly; the shipped graph is App → RootFeature
  → AccountFeature, AuthFeature, NotesListFeature (→ NoteEditorFeature).
  AGENTS.md "Layout" omits RootFeature. Docs only: list every module that has
  a `Project.swift` and redraw the graph from the manifests.
  Acceptance: README and AGENTS.md list every module directory; the README
  graph matches the `.project(target:)` entries in the manifests.

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
- [x] Declare the feature test-bundle dependencies and gate them in CI (Tasker #521)
- [x] Correct docs/local-caching.md and the AGENTS.md persistence convention against the shipped code (Tasker #522)
- [x] Run the macOS test suite in CI next to iOS (Tasker #539)
