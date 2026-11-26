# Indigo Migration Guide

This guide walks an existing SwiftUI project through migrating to Indigo, a
modular SwiftUI app template managed by Tuist. The template ships The
Composable Architecture (TCA) for state, SQLiteData/GRDB for persistence, and
SwiftSharing for reactive state, organized as one app target plus one
framework project per module.

Every pin, path, and code excerpt below reflects the manifests that ship with
this repository. When this guide and the manifests disagree, the manifests win;
please fix the guide.

## Shipped toolchain

| Tool | Version | Where it is pinned |
| --- | --- | --- |
| Tuist | 4.208.0 | `mise.toml` |
| Xcode upgrade check | 27.2 | `Workspace.swift` (`lastXcodeUpgradeCheck`) |
| Swift tools | 6.4 | `Package.swift` (`swift-tools-version`) |
| Swift language mode | 6 | `Package.swift` (`swiftLanguageModes`), `SWIFT_VERSION = 6.0` |
| Deployment targets | iOS 26.0 / macOS 26.0 | `Tuist/ProjectDescriptionHelpers/Project+Templates.swift` (`DeploymentTargets.platforms`) |

Always run Tuist through `mise exec --`: `mise.toml` pins the version, and a
stale `PATH` binary corrupts SPM state.

## Project structure

```text
ProjectRoot/
├── App/                  # App target: entry point, screens, entitlements
│   ├── Project.swift
│   ├── Sources/
│   ├── Resources/
│   ├── Tests/
│   ├── ios.entitlements
│   └── mac.entitlements
├── Core/                 # Models, database + migrations, clients
├── Components/           # Dependency-free reusable SwiftUI components
├── RootFeature/          # Session shell (notes list, auth/account sheets, sign-out)
├── NotesListFeature/     # Example TCA feature
├── NoteEditorFeature/    # Example TCA feature
├── AuthFeature/          # Sign-in, sign-up, forgot-password forms
├── AccountFeature/       # Signed-in profile screen
├── Configs/              # Debug.xcconfig, Release.xcconfig, Local.xcconfig.example
├── Tuist/
│   └── ProjectDescriptionHelpers/
│       ├── Config.swift            # teamReverseDomain, appTarget
│       └── Project+Templates.swift # .indigoFoundation, Project.framework
├── Tuist.swift
├── Workspace.swift       # Workspace plus the AllTests scheme
├── Package.swift         # External dependencies
├── mise.toml             # Tuist version pin
└── README.md
```

Each module directory carries its own `Project.swift` and is its own framework
target — not a folder under `App`. The workspace registers:

```swift
// Workspace.swift (excerpt)
projects: [
  "App",
  "Core",
  "Components",
  "AccountFeature",
  "AuthFeature",
  "NoteEditorFeature",
  "NotesListFeature",
  "RootFeature"
]
```

## Prerequisites

- An existing SwiftUI project (iOS and/or macOS)
- Xcode 27.2 or later (Swift 6.4 toolchain)
- [mise](https://mise.jdx.dev/) for the pinned Tuist toolchain
- Basic familiarity with Swift Package Manager

## Migration steps

### Step 1: Set your identity

Edit `Tuist/ProjectDescriptionHelpers/Config.swift`:

```swift
import ProjectDescription

public let teamReverseDomain = "com.yourcompany" // Replace with your reverse domain
public let appTarget: TargetReference = "YourApp" // Replace with your app name
```

`teamReverseDomain` becomes the prefix of every bundle identifier
(`"\(teamReverseDomain).\(name)"`), and `appTarget` names the app target, its
scheme (`YourApp`, `YourApp Release`), its test target
(`YourAppTests`), and the workspace (`YourApp.xcworkspace`). These two values
are the only places you must personalize.

### Step 2: Install the toolchain

```bash
# Install mise, which reads mise.toml and installs the pinned Tuist
curl https://mise.jdx.dev/install.sh | sh

# Install the pinned Tuist (4.208.0)
mise install

# Resolve the SPM dependencies declared in Package.swift
mise exec -- tuist install
```

### Step 3: Inventory your existing project

From your existing Xcode project, collect:

- **External dependencies** — every package URL and version from the Package
  Manager pane.
- **Build settings** — `MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`,
  bundle identifier, deployment targets, entitlements, custom settings and
  Info.plist keys.
- **Code and resources** — Swift sources, asset catalogs, and any other
  resources.

### Step 4: Declare external dependencies

External packages are declared once in the root `Package.swift` and flow to
targets through the `.indigoFoundation` helper (see Step 6). The shipped file
looks like this:

```swift
// swift-tools-version: 6.4
@preconcurrency import PackageDescription

#if TUIST
  import ProjectDescription

  var productTypes = frameworkProductTypes([
    "Algorithms",
    // Every product that should link as a framework, e.g.:
    "ComposableArchitecture",
    "GRDB",
    "SQLiteData",
    "Sharing",
    // ...
  ])

  let packageSettings = PackageSettings(
    productTypes: productTypes,
    targetSettings: sharingTargetSettings([
      "ComposableArchitecture",
      "JWTAuth",
      "SQLiteData"
    ])
  )
#endif

let package = Package(
  name: "Indigo",
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.2"),
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.11.1"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.12.0"),
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.10.1"),
    // Add your extracted dependencies here
  ],
  swiftLanguageModes: [.v6]
)
```

To add one external package to this template:

1. Add the package to the `dependencies` list in `Package.swift`.
2. Add its product to `frameworkProductTypes` in `Package.swift`.
3. Add `.external(name:)` to `.indigoFoundation` in
   `Tuist/ProjectDescriptionHelpers/Project+Templates.swift`.
4. Run `mise exec -- tuist install && mise exec -- tuist generate --no-open`.

Centralizing products in `.indigoFoundation` prevents double-linking: a
target never declares an external dependency directly, it inherits the helper
array.

The `Sharing` product ships with a module alias applied via
`sharingTargetSettings`: targets get
`OTHER_SWIFT_FLAGS = -module-alias Sharing=SwiftSharing` so the `import
Sharing` name keeps working while the compiled module is `SwiftSharing`. The
Tuist helper reapplies that flag to local targets through `usesSharing`
(Step 6).

### Step 5: Build configurations

`App/Project.swift` maps two configurations to two shipped xcconfig files:

- `Configs/Debug.xcconfig` — recommended warning settings, `DEBUG` condition,
  `DISPLAY_NAME="Indigo Dev"`, `MARKETING_VERSION`.
- `Configs/Release.xcconfig` — the release counterparts,
  `DISPLAY_NAME="Indigo"`.

Both files end with an optional include of a per-developer override file. Copy
`Configs/Local.xcconfig.example` to `Configs/Local.xcconfig` (git-ignored) and
set your Apple Developer Team ID there:

```config
DEVELOPMENT_TEAM=YOUR_TEAM_ID
```

Keep custom build settings in these xcconfig files instead of duplicating them
per target.

### Step 6: Use the framework helper

`Tuist/ProjectDescriptionHelpers/Project+Templates.swift` defines the single
factory every module project uses:

```swift
extension Project {
  public static func framework(
    name: String,
    reverseDomain: String = teamReverseDomain,
    dependencies: [TargetDependency] = [],
    testDependencies: [TargetDependency] = [],
    usesSharing: Bool = false,
    usesDebugTools: Bool = false
  ) -> Project
}
```

It creates the framework target plus a `\(name)Tests` unit-test target, both
with `destinations: .destinations` (iPhone, iPad, Mac) and
`deploymentTargets: .platforms` (iOS 26.0, macOS 26.0). Its shared base
settings include `ENABLE_MODULE_VERIFIER`, `ENABLE_USER_SCRIPT_SANDBOXING`,
`MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS = "gnu11 gnu++14"`,
`STRING_CATALOG_GENERATE_SYMBOLS`, `DEFINES_MODULE = NO`, and
`SWIFT_VERSION = 6.0`.

Three switches matter:

- **`usesSharing`** — pass `true` from any target whose sources `import
  Sharing`. The flag applies
  `OTHER_SWIFT_FLAGS = "$(inherited) -module-alias Sharing=SwiftSharing"` to
  the framework target **and** its generated test bundle, so tests can import
  `Sharing` too.
- **`usesDebugTools`** — pass `true` to depend on `.debugTools` (the Pulse
  network logger and PulseUI) in Debug builds only. The flag also applies
  `SettingsDictionary.debugToolsSettings`
  (`EXCLUDED_SOURCE_FILE_NAMES[config=Release] = Pulse*.framework`), so no
  Pulse binary ships in Release. Import them only under `#if DEBUG`.
- **`dependencies` / `testDependencies`** — combine local `.project(target:)`
  edges with `.indigoFoundation` for the shared externals.

### Step 7: Create module projects

Each module directory holds a small `Project.swift` built on the helper. The
shipped examples are the pattern to copy:

```swift
// Core/Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "Core",
  dependencies: .indigoFoundation,
  testDependencies: .indigoFoundation,
  usesSharing: true,
  usesDebugTools: true
)
```

```swift
// NotesListFeature/Project.swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "NotesListFeature",
  dependencies: [
    .project(target: "Core", path: .relativeToRoot("Core")),
    .project(target: "NoteEditorFeature", path: .relativeToRoot("NoteEditorFeature"))
  ] + .indigoFoundation,
  testDependencies: [
    .project(target: "Core", path: .relativeToRoot("Core")),
    .project(target: "NoteEditorFeature", path: .relativeToRoot("NoteEditorFeature"))
  ] + .indigoFoundation
)
```

`Components` is the dependency-free tier: it declares no dependencies at all.

The app target is declared directly in `App/Project.swift` rather than through
`Project.framework`, because it is an `.app` product with per-platform
entitlements (`ios.entitlements` / `mac.entitlements` selected by SDK), the
two xcconfig-backed configurations, launch-screen Info.plist keys, and
`.indigoFoundation` + `.debugTools` appended to its dependencies by hand. Copy
that file and rename the references through `Config.swift` values
(`appTarget.targetName`), which it already uses.

### Step 8: Follow the module naming conventions

- Name the `@Reducer` after the module: `XFeature` — `NotesListFeature`,
  `AuthFeature`, and so on.
- Name the SwiftUI view `XView` — `NotesListView`.

```swift
// UserProfile/Sources/UserProfileFeature.swift
import ComposableArchitecture
import SwiftUI

@Reducer
struct UserProfileFeature {
  // State, Action, and reducer body
}

struct UserProfileView: View {
  @Bindable var store: StoreOf<UserProfileFeature>

  var body: some View {
    // View implementation
  }
}
```

### Step 9: Register the module in the workspace

Add your module's directory to `projects` in `Workspace.swift`, and add its
test bundle to the workspace-level `AllTests` scheme:

```swift
// Workspace.swift (excerpt)
.testableTarget(
  target: .project(path: "NotesListFeature", target: "NotesListFeatureTests")
)
```

A project-level scheme can only reference its own project's targets, so
`AllTests` lives at the workspace level and aggregates every module's tests
into one run-all surface. Run it with the platform flag shown in Step 11, or
select it in Xcode.

### Step 10: Move your code in

For the first working build, place everything in `App/Sources/`:

- Copy all Swift files, preserving folder structure and imports.
- Move asset catalogs and other resources to `App/Resources/`.
- Copy your entitlements to `App/ios.entitlements` and `App/mac.entitlements`.
- Copy tests into `App/Tests/`.

### Step 11: Generate and verify

The Xcode project is generated — never hand-edit the `.xcworkspace` or
`.xcodeproj`; change the manifests and regenerate.

```bash
mise exec -- tuist generate --no-open
```

Then run every module's tests. The project has multi-platform targets, so
always pass a platform — never run `tuist build` or `tuist test` without one:

```bash
mise exec -- tuist test AllTests --platform macos --no-selective-testing
```

Open `Indigo.xcworkspace`, select the `Indigo` scheme, and run the app on an
iOS simulator or on My Mac.

### Step 12: Refactor gradually

With the app building from `App/Sources/`, extract code into the module tiers,
regenerating and re-running `AllTests` after each move:

- **Components** — reusable SwiftUI views with no external dependencies.
- **Core** — models, the database, and API clients. Reads go through clients
  (`NotesClient` → `database.read`); writes use the structured query API.
- **Features** — one TCA feature per framework target, depending on `Core`,
  `Components`, and `.indigoFoundation`, wired into `RootFeature`.

Remove dependencies from the app target as features take them over, and keep
import statements pointing at module names.

### Step 13: Troubleshooting

- **Undefined symbols for a third-party product** — the target did not inherit
  `.indigoFoundation`, or the product is missing from `frameworkProductTypes`
  in `Package.swift`. Complete the four-step recipe in Step 4, then
  regenerate.
- **`Sharing` vs `SwiftSharing` mismatch** — a target imports `Sharing` but
  does not carry the module-alias flag. Set `usesSharing: true` (frameworks)
  or add `-module-alias Sharing=SwiftSharing` to `OTHER_SWIFT_FLAGS` (the app
  target and its tests set it by hand).
- **Pulse appears in a Release build** — a target added `.debugTools` without
  also applying `SettingsDictionary.debugToolsSettings`, or a framework forgot
  `usesDebugTools: true`. Release must never link Pulse.
- **Resources not found** — Tuist generates resource accessors; reference
  resources through those accessors and keep them under the target's
  `Resources/` folder.
- **Signing fails on device** — set `DEVELOPMENT_TEAM` in
  `Configs/Local.xcconfig` (Step 5).
- **Dependency-graph surprises** — audit the graph after structural changes:

  ```bash
  mise exec -- tuist inspect dependencies
  ```

## Verification checklist

- [ ] `mise exec -- tuist generate --no-open` succeeds without warnings about your modules
- [ ] `mise exec -- tuist test AllTests --platform macos --no-selective-testing` passes
- [ ] All resources resolve through generated accessors
- [ ] The app runs on an iOS simulator and on macOS
- [ ] `mise exec -- tuist inspect dependencies` reports no implicit or redundant dependencies
- [ ] Device builds sign with the team from `Configs/Local.xcconfig`

## Command reference

```bash
mise install                                                 # Install the pinned Tuist
mise exec -- tuist install                                   # Resolve SPM dependencies
mise exec -- tuist generate --no-open                        # Regenerate the Xcode project
mise exec -- tuist test AllTests --platform macos --no-selective-testing
mise exec -- tuist inspect dependencies                      # Audit the dependency graph
mise exec -- tuist edit                                      # Open the manifests in a scratch project
mise exec -- tuist clean                                     # Remove local artifacts
```

Run every command through `mise exec --` so the pinned Tuist version is used.
Never run `tuist build` or `tuist test` without `--platform`: the generated
project has multi-platform targets.
