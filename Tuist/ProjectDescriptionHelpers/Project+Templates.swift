import ProjectDescription

extension Array where Element == TargetDependency {
  public static var indigoFoundation: [TargetDependency] {
    [
      .external(name: "Algorithms"),
      .external(name: "Collections"),
      .external(name: "ComposableArchitecture"),
      .external(name: "ComposableToasts"),
      .external(name: "Dependencies"),
      .external(name: "DependenciesMacros"),
      .external(name: "GRDB"),
      .external(name: "HTTPRequestBuilder"),
      .external(name: "HTTPRequestClient"),
      .external(name: "JWTAuth"),
      .external(name: "JWTDecode"),
      .external(name: "Logging"),
      .external(name: "Perception"),
      .external(name: "Sharing"),
      .external(name: "SQLiteData"),
      .external(name: "SimpleKeychain"),
      .external(name: "SwiftNavigation")
    ]
  }

  /// Debug-only tools: the Pulse network logger and its console UI.
  ///
  /// Kept out of `.indigoFoundation` so Release never links them. Any target
  /// that depends on these must also apply `SettingsDictionary.debugToolsSettings`,
  /// and must only `import` them under `#if DEBUG`.
  public static var debugTools: [TargetDependency] {
    [
      .external(name: "Pulse"),
      .external(name: "PulseUI")
    ]
  }
}

extension ProjectDescription.SettingsDictionary {
  /// Drops the `.debugTools` frameworks from the link and embed phases of
  /// Release builds, so no Pulse binary ships in a Release product.
  ///
  /// Apply to every target that depends on `.debugTools`, and to the app
  /// target, which embeds them transitively.
  public static var debugToolsSettings: SettingsDictionary {
    ["EXCLUDED_SOURCE_FILE_NAMES[config=Release]": "Pulse*.framework"]
  }
}

extension Project {
  /// Creates a framework project with the shared Indigo base settings.
  ///
  /// - Parameters:
  ///   - usesSharing: Pass `true` from any target that imports `Sharing`.
  ///     The product ships aliased as `SwiftSharing`, so the flag applies
  ///     `-module-alias Sharing=SwiftSharing` to the framework target **and**
  ///     its generated test bundle.
  ///   - usesDebugTools: Pass `true` to depend on `.debugTools` (Pulse) in
  ///     Debug builds only. Release builds do not link them.
  public static func framework(
    name: String,
    reverseDomain: String = teamReverseDomain,
    dependencies: [TargetDependency] = [],
    testDependencies: [TargetDependency] = [],
    usesSharing: Bool = false,
    usesDebugTools: Bool = false
  ) -> Project {
    var baseSettings: SettingsDictionary = [
      "DEFINES_MODULE": "NO",
      "SWIFT_VERSION": "6.0"
    ]
    var testSettings: SettingsDictionary = [:]
    if usesSharing {
      baseSettings["OTHER_SWIFT_FLAGS"] = "$(inherited) -module-alias Sharing=SwiftSharing"
      testSettings["OTHER_SWIFT_FLAGS"] = "$(inherited) -module-alias Sharing=SwiftSharing"
    }
    if usesDebugTools {
      baseSettings.merge(.debugToolsSettings) { $1 }
    }

    return .init(
      name: name,
      settings: .settings(
        base: [
          "ENABLE_MODULE_VERIFIER": "YES",
          "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
          "MODULE_VERIFIER_SUPPORTED_LANGUAGE_STANDARDS": "gnu11 gnu++14",
          "STRING_CATALOG_GENERATE_SYMBOLS": "YES"
        ]
      ),
      targets: [
        .target(
          name: name,
          destinations: .destinations,
          product: .framework,
          bundleId: "\(reverseDomain).\(name)",
          deploymentTargets: .platforms,
          sources: ["Sources/**"],
          resources: ["Resources/**"],
          dependencies: dependencies + (usesDebugTools ? .debugTools : []),
          settings: .settings(
            base: baseSettings
          )
        ),
        .target(
          name: "\(name)Tests",
          destinations: .destinations,
          product: .unitTests,
          bundleId: "\(reverseDomain).\(name)Tests",
          sources: ["Tests/**"],
          resources: ["Tests/Resources/**"],
          dependencies: [.target(name: name)] + testDependencies,
          settings: .settings(
            base: testSettings
          )
        )
      ]
    )
  }
}

extension ProjectDescription.DeploymentTargets {
  public static var platforms: DeploymentTargets {
    .multiplatform(
      iOS: "26.0",
      macOS: "26.0",
      watchOS: nil,
      tvOS: nil,
      visionOS: nil
    )
  }
}

extension ProjectDescription.Destinations {
  public static var destinations: Destinations {
    [.iPad, .iPhone, .mac]
  }
}
