# AGENTS.md

## Start here
- Read `.cursorrules` and `CLAUDE.md` before making changes.
- Keep scope to one logical change per task.
- Target the `develop` branch and use conventional commits: `fix:`, `feat:`, `chore:`, `build:`, `refactor:`, `test:`, `docs:`.
- Prefer the lowest dependency tier that can satisfy the task.

## Project snapshot
- Provenance is an iOS/tvOS emulator frontend built from many `PV*` Swift packages plus Objective-C / Objective-C++ bridge layers for emulator cores.
- Main app targets live in `Provenance/`, `ProvenanceTV/`, and `Extensions/`.
- Emulator bridge work usually lives under each core directory in `Cores/<CoreName>/` or in `CoresRetro/RetroArch/`.
- Persistence uses Realm and CloudKit. Realm objects are thread-confined; pass object identifiers or frozen objects across threads.

## Hard constraints
- Do not modify upstream submodule source under `Cores/<name>/<upstream-dir>/`.
- **`CoresRetro/RetroArch/RetroArch/`** is a **Provenance-maintained RetroArch fork** (not read-only upstream). Edit when needed for integration; keep diffs minimal and intentional.
- Do not modify `CodeSigning.xcconfig`.
- Avoid `project.pbxproj` changes unless there is no viable package-based alternative.
- Prefer `Package.swift` updates over Xcode project edits whenever possible.
- Avoid touching generated files such as `Version.h`, `Version.swift`, or build output under generated directories.
- Preserve existing comments and logic unless the task explicitly requires changing them.

## Module tiers
- Tier 0: `PVObjCUtils`, `PVFeatureFlags`, `PVCheevos`
- Tier 1: `PVLogging`, `PVPlists`, `PVHashing`
- Tier 2: `PVSettings`, `PVPrimitives`
- Tier 3: `PVSupport`, `PVAudio`, `PVCoreAudio`
- Tier 4: `PVCoreBridge`, `PVEmulatorCore`, `PVShaders`
- Tier 5: `PVCoreBridgeRetro`, `PVCoreLoader`, `PVLookup`, `PVLibrary`
- Tier 6: `PVUI`, app targets

## Swift and platform conventions
- Use 4-space indentation and keep lines within the repo's 200-character limit.
- Prefer `async` / `await` for new asynchronous work.
- Prefer `guard` / optional binding over force unwraps in production code.
- When adding or changing Swift APIs, add concise `///` documentation comments where they help future readers.
- Prefer protocol-oriented designs when they simplify the implementation.
- Assume Swift changes must work for both iOS and tvOS. Guard unsupported APIs with conditional compilation.
- Do not add comments that merely restate the code.

## Validation guidance
- For Tier 0-2 modules, validate locally with `swift build` or `swift test` inside the module when the change is testable.
- Run `swiftlint lint --path <changed-swift-file>` for changed Swift files when `swiftlint` is available.
- For higher-tier modules and app targets, validate from `Provenance.xcworkspace`.
- Start with the `Provenance-Lite` scheme for the fastest Xcode validation.
- If an initial Xcode build fails because generated sources are missing, retry once before investigating further.
- Do not run full iOS/tvOS command-line builds unless the user explicitly asks for them.

## Cursor Cloud specific instructions
- Cursor Cloud agents here run on Linux, so Xcode, Simulator, and Apple platform runtime validation are unavailable.
- In this environment, fully validate docs changes and any standalone Swift Package work that can run without Xcode.
- For workspace-level iOS/tvOS changes that require Xcode, do the best possible static review, run any repo checks that are available, and clearly call out the Mac-only validation that still needs to happen.
- Never claim an app runtime or simulator change is verified unless it was actually exercised on macOS with Xcode.

## Quick commands
- `swiftlint lint --path <file>`
- `cd PV<Module> && swift build`
- `cd PV<Module> && swift test`
