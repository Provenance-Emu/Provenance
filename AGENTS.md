# AGENTS.md

## Cursor Cloud specific instructions

### Environment overview

Provenance is an iOS/tvOS emulator frontend. The full app build requires **macOS with Xcode 16.2** — it cannot be built on Linux. The Cloud Agent VM runs Ubuntu 24.04 (Linux), so the development scope is limited to:

- **SwiftLint** — runs on the full codebase (`swiftlint lint` from repo root; see `.swiftlint.yml` for config)
- **SPM leaf modules (Tier 0)** — `PVFeatureFlags` can be built and tested on Linux with `swift build` / `swift test`
- **Code editing and review** — all Swift/ObjC source files are accessible

### What works on Linux

| Task | Command | Notes |
|------|---------|-------|
| Lint all files | `swiftlint lint` (from repo root) | Uses `.swiftlint.yml` config |
| Lint single file | `swiftlint lint <path>` | Useful for changed files |
| Build PVFeatureFlags | `cd PVFeatureFlags && swift build` | Only Tier 0 module that compiles on Linux |
| Test PVFeatureFlags | `cd PVFeatureFlags && swift test` | 14 tests |

### What does NOT work on Linux

- **PVLogging, PVCheevos, PVHashing, PVSettings, PVPlists** — depend on Apple-only frameworks (`OSLog`, `FoundationNetworking` differences, platform SDKs)
- **Full app builds** (`xcodebuild`, `make ios`, `make tvos`, `make lite`) — require macOS + Xcode
- **`make test`** / fastlane — requires macOS + Ruby + Bundler + Xcode
- **SwiftFormat** — not installed; use SwiftLint for linting

### Key caveats

- Swift 6.0.2 is installed at `/opt/swift/usr/bin/swift`. The PATH is configured in `~/.bashrc`.
- SwiftLint 0.63.2 is installed at `/usr/local/bin/swiftlint`.
- The `.swiftlint.yml` already excludes `Cores/`, `Carthage/`, `Scripts/`, `fastlane/`, `.build/` directories.
- The `CLAUDE.md` file has comprehensive build, architecture, and convention docs — refer to it for project conventions.
- Do NOT modify submodule source in `Cores/<name>/<upstream-dir>/`, `CodeSigning.xcconfig`, or `project.pbxproj` unless absolutely necessary.
- For standard development commands (build schemes, testing, CI), see `CLAUDE.md` and the `Makefile`.
