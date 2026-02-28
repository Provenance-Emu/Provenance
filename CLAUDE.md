# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Provenance is a multi-platform emulator frontend for iOS/tvOS supporting 60+ retro gaming systems. Written primarily in Swift with Objective-C/C++ bridge layers for emulator cores.

## Build & Development

### Prerequisites
- Xcode 16.2 (`/Applications/Xcode_16.2.app`)
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
