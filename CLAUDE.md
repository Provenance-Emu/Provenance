# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Provenance is a multi-platform emulator frontend for iOS/tvOS supporting 60+ retro gaming systems. Written primarily in Swift with Objective-C/C++ bridge layers for emulator cores.

## Build & Development

### Prerequisites
- Xcode 16.x or Xcode 26+ (use `xcode-select -p` to confirm active version; both are supported)
- Ruby + Bundler (for fastlane)
- `make setup` to install all dependencies

### Code Signing
Copy `CodeSigning.xcconfig.sample` to `CodeSigning.xcconfig` and fill in your developer account details.

### Building
```bash
make open          # Open Provenance.xcworkspace in Xcode
make ios           # Update submodules + build iOS
make tvos          # Update submodules + build tvOS
make update        # Pull + update submodules + install gems
make test          # Run tests via fastlane
```

Build from Xcode: open `Provenance.xcworkspace` and select a scheme. Start with `Provenance-Lite` (fastest build) before moving to `Provenance-Release` or `Provenance-XL (Release)`.

**Note:** Initial builds may fail because some source files are generated lazily at compile time. Retry if Xcode gets the build order wrong on first build.

### Schemes
- **Provenance-Lite (AppStore)** — lightweight, fewer cores
- **Provenance (AppStore)** — standard release
- **Provenance-XL (Release)** — includes more RetroArch and native cores
- Each has iOS and tvOS variants

### CI
GitHub Actions (`.github/workflows/build.yml`) builds all target variants on push/PR to `develop` and `master`.

## Architecture

### Module Structure
The app is split into ~26 `PV*` Swift Package frameworks. Key modules:

- **PVLibrary** — Data models, Realm persistence, game database, CloudKit sync
- **PVCoreBridge** — Protocol/bridge between app and emulator cores
- **PVCoreBridgeRetro** — RetroArch-specific core bridge
- **PVCoreLoader** — Dynamic loading of emulator core packages
- **PVEmulatorCore** — Base classes for emulator implementations
- **PVUI** — SwiftUI-based shared UI components
- **PVSettings** — User preferences
- **PVCoreAudio / PVAudio** — Audio engine and playback
- **PVSupport** — Shared utilities
- **PVLogging** — Logging infrastructure (CocoaLumberjack-based)
- **PVPrimitives** — Base data types shared across modules
- **PVCheevos** — RetroAchievements integration
- **PVHashing** — ROM file hashing for identification
- **PVLookup** — Game metadata lookup
- **PVJIT** — JIT compilation support for emulator cores

### Emulator Cores (`Cores/`)
Each core lives in `Cores/<CoreName>/` and typically contains:
- A git submodule with the upstream emulator source
- An Xcode project (`PV<Core>.xcodeproj`) and/or `Package.swift`
- A bridge layer (`PV<Core>Core/`) with `PV<Core>CoreBridge+Controls.mm` (Objective-C++) connecting the emulator to `PVCoreBridge`

Cores depend on `PVEmulatorCore`, `PVCoreBridge`, `PVSupport`, `PVObjCUtils`, and `PVLogging` via relative SPM paths.

RetroArch-based cores live in `CoresRetro/RetroArch/` and use `PVCoreBridgeRetro`.

### App Targets
- **Provenance/** — Main iOS app
- **ProvenanceTV/** — tvOS-specific app target
- **Extensions/** — Spotlight indexing, TopShelf (tvOS)

### Persistence
- **Realm** for local metadata, game library, and CloudKit record IDs
- **CloudKit** for syncing ROMs, save states, and BIOS files across devices
- Realm objects are thread-confined: pass Object IDs or freeze objects for cross-thread access (see DEVELOPER.md for patterns)

### Key Patterns
- CloudKit syncers manage records by directory scope (ROMs, Save States, BIOS) with deterministic record IDs
- Emulator cores are loaded as dynamic packages at runtime via `PVCoreLoader`
- Controller input mapping is handled per-core in `*Bridge+Controls.mm` files

## Linting & Formatting

**SwiftLint** (`.swiftlint.yml`):
- Line length: 200 chars
- Only lints: `Provenance`, `ProvenanceTV`, `PVLibrary`, `PVSupport`, `TopShelf`, `Spotlight`
- Excludes: `Cores`, `Carthage`, `Scripts`, `fastlane`, `.build`
- `force_cast` and `force_try` are warnings (not errors)

**SwiftFormat** (`.swiftformat`):
- 4-space indent, no indent for `case`
- Excludes: `Carthage`, `Cores`

## Important Conventions

- The `develop` branch is the main development branch
- Emulator core submodules are in `Cores/<name>/<upstream-submodule-dir>` — avoid modifying upstream source directly
- Each PV* module is a standalone Swift Package with its own `Package.swift`
- The top-level `Package.swift` is minimal (legacy SPM support for PVLibrary only); the real build system is the Xcode workspace
- Build variants (Lite/Standard/XL) differ in which cores are included; see `CoresRetro/RetroArch/Scripts/` for core lists per target

## Agent Development Guidelines

### Quick Validation Commands
```bash
# Lint changed Swift files
swiftlint lint --path <file>

# Build a standalone SPM module (Tier 0-2 only)
cd PV<Module> && swift build

# Test a standalone SPM module
cd PV<Module> && swift test

# Xcode simulator build (full app, slow)
xcodebuild build -workspace Provenance.xcworkspace \
  -scheme "Provenance-Lite (AppStore)" \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO | xcpretty
```

### Module Dependency Tiers
Modules are organized by dependency depth. Agents should scope changes to the lowest tier possible.

| Tier | Modules | Can `swift build` standalone? |
|------|---------|------------------------------|
| 0 | PVObjCUtils, PVFeatureFlags, PVCheevos | Yes |
| 1 | PVLogging, PVPlists, PVHashing | Yes |
| 2 | PVSettings, PVPrimitives | Yes |
| 3 | PVSupport, PVAudio, PVCoreAudio | Needs Xcode |
| 4 | PVCoreBridge, PVEmulatorCore, PVShaders | Needs Xcode |
| 5 | PVCoreBridgeRetro, PVCoreLoader, PVLookup, PVLibrary | Needs Xcode |
| 6 | PVUI, App targets | Full workspace build |

### Emulator Core Bridge Pattern
Each core has a `PV<Core>CoreBridge+Controls.mm` file that maps controller input:
```objc
- (void)didMoveGamepad:(GCExtendedGamepad *)gamepad {
    // Map GCController buttons to emulator-specific button constants
    // Use PVCoreBridge protocol methods to forward input
}
```
When modifying bridge files, ensure all controller types are handled (Extended, Micro, Keyboard).

### What NOT to Modify
- **GitHub workflow files** — `.github/workflows/*.yml` cannot be pushed by GitHub Actions bots (requires `workflows` permission). If a task needs a new workflow, write the content to a comment or PR description and note that a maintainer must add it manually. Do NOT include workflow files in agent PR commits — the push will fail silently.
- **Submodule source** — `Cores/<name>/<upstream-dir>/` contents are upstream code
- **Generated files** — `Version.h`, `Version.swift`, files in `cmake/` build dirs
- **CodeSigning.xcconfig** — contains developer-specific credentials
- **project.pbxproj** — editing is permitted and sometimes required (e.g., adding new app targets). When you add a new target, use deterministic UUID prefixes (e.g. `C0C0CAFE...`) to make additions easy to identify. Use `PBXFileSystemSynchronizedRootGroup` for source directories (Xcode 16+). Prefer minimal diffs — only touch the sections that need changing.
- **Upstream RetroArch** — `CoresRetro/RetroArch/RetroArch/` is a submodule

### Minimum Deployment Targets

Provenance targets **iOS 17+, tvOS 17+, macOS 14+ (Catalyst), visionOS 1+**. All new code MUST be written against these minimum versions — do **not** add availability guards or fallbacks for APIs available since iOS 17 or earlier.

**Prefer modern Swift/SwiftUI APIs** when the minimum deployment target supports them:

| Prefer (iOS 16+/17+) | Over (older) |
|---|---|
| `ShareLink` | `UIActivityViewController` wrapped in `UIViewControllerRepresentable` |
| `@Observable` macro (iOS 17+) | `@ObservableObject` + `@Published` |
| `NavigationStack` | `NavigationView` |
| `.navigationBarTitleDisplayMode(.inline)` on non-tvOS | conditional guard |
| `UIWindowScene.keyWindow` | `UIApplication.shared.keyWindow` (deprecated iOS 13) |

**`@StateObject` vs `@ObservedObject` rule:**
- `@StateObject` — use only when the view **creates and owns** the object's lifetime (new instances).
- `@ObservedObject` — use for **singletons** (e.g. `Foo.shared`) and objects passed in from outside.
  Using `@StateObject` with a singleton is semantically wrong even though it compiles.

### Pre-PR Validation (MANDATORY)
Agents MUST run these checks before creating a PR. Do NOT skip any step.

1. **Compile check** — Every changed file must compile. For Tier 0-2 modules: `cd PV<Module> && swift build`. For higher tiers or ObjC files: verify syntax is correct (no undefined symbols, no mismatched types, no missing imports).

2. **Lint** — Run `swiftlint lint --path <file>` on every changed Swift file.

3. **Unit tests** — If the module has tests, run them: `cd PV<Module> && swift test`. If adding new logic, add test coverage.

4. **No dead code** — Don't add unused properties, unused imports, or commented-out code blocks. If Copilot flags dead code, that means you should have caught it.

5. **No magic numbers** — Extract constants. Don't hardcode values that are used in multiple places.

6. **Use `SystemIdentifier` enum, not raw strings** — Never compare system identifiers using raw string literals like `"com.provenance.n64"`. Use the `SystemIdentifier` enum from `PVPrimitives`:

   ```swift
   // ❌ WRONG — fragile, typo-prone, no compile-time safety
   if self.systemIdentifier == "com.provenance.n64" { ... }
   if self.systemIdentifier?.contains("atarist") == true { ... }

   // ✅ CORRECT — type-safe, refactor-safe
   if SystemIdentifier(rawValue: self.systemIdentifier ?? "") == .N64 { ... }

   // ✅ CORRECT — check multiple systems
   let sysID = SystemIdentifier(rawValue: self.systemIdentifier ?? "")
   if sysID == .SNES || sysID == .NES { ... }

   // ✅ CORRECT — switch
   switch SystemIdentifier(rawValue: self.systemIdentifier ?? "") {
   case .AtariST: setupHatari()
   case .DOS, .DOOM: setupDOSBox()
   default: break
   }
   ```

   In **Objective-C** there is no enum, so use the `SystemIdentifier` raw string constants directly via `PVSystem` or define a local `NSString * const` — do NOT embed the `com.provenance.*` string inline more than once:

   ```objc
   // ❌ WRONG
   if ([self.systemIdentifier containsString:@"com.provenance.atarist"]) { ... }

   // ✅ CORRECT — define a constant or use the existing PVSystem identifier
   static NSString * const PVAtariSTSystemIdentifier = @"com.provenance.atarist";
   if ([self.systemIdentifier isEqualToString:PVAtariSTSystemIdentifier]) { ... }
   ```

   The `SystemIdentifier` enum is in `PVPrimitives/Sources/PVSystems/SystemIdentifier.swift`. Import `PVPrimitives` to use it. `systemIdentifier` on the core (`PVEmulatorCore`) is a `String?`.

7. **Type safety** — Check that optional unwrapping is correct (no double-optionals from `?.` chains). Check that enum cases exist before referencing them. Check that function signatures match call sites.

8. **Thread safety** — If reading a property from a background queue that's written from main, snapshot it into a local `let` first. Don't use `@Published` properties across threads without synchronization.

9. **Multi-platform compilation** — Provenance builds for **iOS, tvOS, macOS (Catalyst), and visionOS**. All new code MUST compile on all platforms. Agents must mentally verify every changed file compiles for at least iOS AND tvOS before creating a PR.

   **Platform guard patterns:**
   - `#if os(iOS)` / `#if os(tvOS)` — OS-specific code
   - `#if !os(tvOS)` — iOS/macOS features unavailable on tvOS (e.g., `DragGesture`, `UIImpactFeedbackGenerator`, `UIDevice.current.orientation`)
   - `#if canImport(UIKit)` — UIKit vs AppKit
   - `#if targetEnvironment(simulator)` — simulator-only code
   - `#if targetEnvironment(macCatalyst)` — Mac Catalyst specifics

   **Common tvOS pitfalls** (these WILL fail to compile on tvOS):
   - `DragGesture` — unavailable on tvOS
   - `UIImpactFeedbackGenerator` / haptics — iOS only
   - `UIDevice.current.orientation` — no orientation on tvOS
   - `.onHover` — not available on tvOS
   - `NavigationSplitView` details differ on tvOS

   **Linux support** — Non-UI SPM modules (Tier 0-2: PVHashing, PVLookup, PVPlists, etc.) should compile and test on Linux. Use `#if canImport(Foundation)` not `#if canImport(UIKit)` for cross-platform code. CI runs `swift test` on Debian runners for these modules.

### PR Requirements
- Target the `develop` branch
- **Include unit tests for new logic** — this is not optional. If you add a new class, manager, or utility, add tests. Use `swift test` for SPM modules.
- Keep scope focused — one logical change per PR
- Run `swiftlint` on changed files before submitting
- Agent PRs should use the `[Agent]` prefix in title
- **All Pre-PR Validation steps above must pass before creating the PR**

### Branch Naming & Commit Messages
- Branches: `agent/issue-<N>` for agent work, `feature/<description>` for features
- Commits: Use conventional commits (`fix:`, `feat:`, `chore:`, `build:`, `refactor:`, `test:`, `docs:`)
- Keep commit messages concise (< 72 chars for subject line)
