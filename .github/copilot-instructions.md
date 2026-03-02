# Copilot Instructions for Provenance

## Project Overview

Provenance is a multi-platform emulator frontend for iOS/tvOS supporting 60+ retro gaming systems. Written primarily in Swift with Objective-C/C++ bridge layers for emulator cores.

## Build & Development

### Prerequisites
- Xcode 16.2 (`/Applications/Xcode_16.2.app`)
- Ruby + Bundler (for fastlane)
- `make setup` to install all dependencies

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
- Realm objects are thread-confined: pass Object IDs or freeze objects for cross-thread access

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

## Code Style

### Swift Code
- Prefer `async/await` over Combine where possible
- Use `@Sendable` and proper actor isolation for concurrency
- Avoid force unwraps (`!`) in production code; use `guard let` or `if let`
- Line length limit: 200 characters (`.swiftlint.yml`)
- 4-space indentation, no indent for `case` in `switch`

### Emulator Core Bridges (`*Bridge+Controls.mm`)
- All controller types must be handled: Extended, Micro, Keyboard
- Button mappings must match upstream emulator constants
- Never modify upstream submodule source in `Cores/<name>/<upstream-dir>/`

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
Modules are organized by dependency depth. Scope changes to the lowest tier possible.

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
- **Submodule source** — `Cores/<name>/<upstream-dir>/` contents are upstream code
- **Generated files** — `Version.h`, `Version.swift`, files in `cmake/` build dirs
- **CodeSigning.xcconfig** — contains developer-specific credentials
- **project.pbxproj** — avoid when possible; prefer SPM Package.swift changes
- **Upstream RetroArch** — `CoresRetro/RetroArch/RetroArch/` is a submodule

### What NOT to Flag in Code Review
- `force_cast` and `force_try` are intentionally warnings, not errors
- Generated files (`Version.h`, `Version.swift`) — skip review
- Submodule contents (`Cores/<name>/<upstream>/`) — skip review
- `project.pbxproj` changes — minimize review noise

### PR Requirements
- Target the `develop` branch
- Include test coverage for new logic (where testable)
- Keep scope focused — one logical change per PR
- Run `swiftlint` on changed files before submitting
- Agent PRs should use the `[Agent]` prefix in title

### Branch Naming & Commit Messages
- Branches: `agent/issue-<N>` for agent work, `feature/<description>` for features
- Commits: Use conventional commits (`fix:`, `feat:`, `chore:`, `build:`, `refactor:`, `test:`, `docs:`)
- Keep commit messages concise (< 72 chars for subject line)
