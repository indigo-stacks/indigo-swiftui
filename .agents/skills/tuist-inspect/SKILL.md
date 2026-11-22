---
name: tuist-inspect
description: Use when the user asks to audit the Tuist dependency graph, verify targets declare their dependencies explicitly, or check there are no double-linked static libraries. Triggers include "tuist inspect", "check dependency graph", "inspect dependencies", "implicit dependencies", or "double linked static libraries".
---

# Inspect Tuist Dependency Graph

Identify any issues in the dependency graph of this project.

## 1. Regenerate from scratch

```sh
mise exec -- tuist generate --no-open --cache-profile none
```

The command should _not_ return double-linked static library warnings:

> Target 'X' has been linked from target 'Y' and target 'Z', it is a static product so may introduce unwanted side effects.

If you find a static target that is linked from multiple targets, make it dynamic by adding it to `Package.swift` as `.framework`.

## 2. Check that every dependency is declared

```sh
mise exec -- tuist inspect dependencies
```

Expected output:

> Loading and constructing the graph
> It might take a while if the cache is empty
> We did not find any issues with your project's dependencies.

The check fails when a target imports a module it does not declare as a
dependency (for example, a test bundle importing a framework that is only a
transitive dependency). Declare the missing dependency in the relevant
`Project.swift` — for generated test bundles, use `testDependencies`.

## Resolution

If an issue is reported:

- **Undeclared dependencies** — add the missing target or external product to the target's `dependencies` (or `testDependencies` for test bundles) in its `Project.swift`.
- **Double-linked static libraries** — change the product type to `.framework` in `Package.swift`.

Raise a flag if any of these checks fail.
