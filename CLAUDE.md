# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Provenance is a multi-platform emulator frontend for iOS/tvOS supporting 60+ retro gaming systems. Written primarily in Swift with Objective-C/C++ bridge layers for emulator cores.

## Build & Development

### Prerequisites
- Xcode 16.x or Xcode 26+ (use `xcode-select -p` to confirm active version; both are supported)
- Ruby + Bundler (for fastlane)
- `make setup` to install all dependencies

- Minimum targets: iOS 17+, tvOS 17+ mandatory. macOS today = "Designed for iPad" (the iOS binary on Apple Silicon); a native macOS target is planned (see docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md). Mac Catalyst is NOT supported. visionOS/watchOS/Linux: SPM packages declare them — keep code compiling with guards, but no app ships for them.

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
- **Provenance-XL (Release)** — includes more RetroArch and native cores, not really used but should be kept updated regardless
- Each is a multi-platform target for iOS, tvOS and macOS Catalyst, and macOS where available. iOS and tvOS are our primary focus with possible future other Apple platform support

### CI
GitHub Actions (`.github/workflows/build.yml`) builds all target variants on push/PR to `develop` and `master`.

- **CI cache can shadow source changes.** `actions/cache@v4` caches `Cores/`, `CoresRetro/`, `Dependencies/`, `PVRcheevos/` for submodule speed. A post-restore step runs `git checkout HEAD -- Cores CoresRetro Dependencies PVRcheevos` to un-shadow parent-repo-tracked files. If a CI build ignores your source changes, check that this step ran successfully.

- **xcbeautify hides Run Script output — don't debug CI from the console log.** The build pipes through `2>&1 | tee /tmp/xcodebuild.log | xcbeautify`, and xcbeautify filters out Run Script phase output. `GetModule:` / `MakeFrameworks:` lines therefore never appear in `gh run view` or `gh api .../jobs/<id>/logs`, even when the script ran fine — an empty grep means "filtered", not "never ran". Those lines exist only in the raw log, which is uploaded on failure as artifact `xcodebuild-log-<IPA_NAME>` (3-day retention):

  ```bash
  gh run download <run-id> -n xcodebuild-log-Provenance-iOS
  ```

  The failure-report step also prints, in order: `: error:` diagnostics, the `The following build commands failed:` block, and the last 100 raw lines. It greps `": (fatal )?error:"` with a **leading colon** on purpose — a bare `"error:"` also matches ObjC selectors like `loadStateToFileAtPath:error:` inside `-Wincomplete-implementation` warnings, which floods the report and buries the real errors. Run Script failures (e.g. "Generate Frameworks" exiting non-zero) produce no `error:` line at all and surface *only* in the `build commands failed` block.

## Architecture

### Module Structure
The app is split into ~26 `PV*` Swift Package frameworks. Key modules:

- **PVAppIntents** — Siri and App intents
- **PVAudio** — Swift audio apis
- **PVCheevos** — RetroAchievements API integration
- **PVCoreAudio / PVAudio** — Audio engine and playback
- **PVCoreBridge** — Protocol/bridge between app and emulator cores
- **PVCoreBridgeRetro** — RetroArch-specific core bridge
- **PVCoreLoader** — Dynamic loading of emulator core packages
- **PVEmulatorCore** — Base classes for emulator implementations
- **PVFeatureFlags** — Feature flags manager
- **PVHashing** — ROM file hashing for identification
- **PVHelp** — SwiftUI wiki and blog parser
- **PVJIT** — JIT compilation support for emulator cores
- **PVLibrary** — Data models, Realm persistence, game database, CloudKit sync
- **PVLogging** — Logging infrastructure (CocoaLumberjack-based)
- **PVLookup** — Game metadata and artwork and cheats lookup
- **PVNetplay** — Central netplay support code for retroarch and game center
- **PVPLlists** — Core and System plist processing and other serializer
- **PVPatching** — Support for patch files for roms (WIP)
- **PVPrimitives** — Base data types shared across modules
- **PVQuicklookSupport** — iOS and macOS Quicklook api support code
- **PVRcheevos** — RetroAchievements C client integration
- **PVSettings** — User preferences
- **PVShaders** — Metal shader manager support
- **PVSupport** — Shared utilities
- **PVThemes** — UI Theming Support
- **PVUI** — SwiftUI-based shared UI components
- **PVWebServer** — Swift/Objective-C SwiftPM module for GCDWebServer and WIP new Swift webserver for webdav and http file management, future REST API

### Emulator Cores (`Cores/`)
Each core lives in `Cores/<CoreName>/` and typically contains:
- A git submodule with the upstream emulator source
- An Xcode project (`PV<Core>.xcodeproj`) and/or `Package.swift`
- A bridge layer (`PV<Core>Core/`) with `PV<Core>CoreBridge+Controls.mm` (Objective-C++) connecting the emulator to `PVCoreBridge`

Cores depend on `PVEmulatorCore`, `PVCoreBridge`, `PVSupport`, `PVObjCUtils`, and `PVLogging` via relative SPM paths.

RetroArch-based cores live in `CoresRetro/RetroArch/` and use `PVCoreBridgeRetro`.

**Core taxonomy — not every `Cores/PV*` directory is an active shipping core.**
- **Active native PV* cores** (custom forks or long-supported legacy we
  actively extend): Mupen, snes9x, Stella, Mednafen, Jaguar, Dolphin,
  FCEU, ProSystem, Genesis-Plus-GX, Flycast, and similar.
- **Placeholder PV* targets** (in the workspace as scaffolding but NOT
  actively used in the shipping app): DuckStation, BeetlePSX, and
  similar — these duplicate libretro cores we now serve via the thin
  wrapper (`PVCoreBridgeRetro/.../PVThinLibretroCore`) against upstream
  libretro buildbot dylibs. Don't extend these PV* shells; the thin
  wrapper is the supported path.
- **Rule of thumb:** if a libretro buildbot dylib already serves the
  core and the thin wrapper handles it, fix the thin wrapper (or the
  upstream dylib via Provenance fork), not the placeholder PV* shell.
  The whole point of the thin wrapper is to make those cores feel
  basically native without per-core PV* maintenance.

**Wrapper platform defaults — patch the right file:**
- **Both iOS and tvOS** now default to the THIN libretro wrapper
  (`PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroFrontend.mm`
  + `PVThinLibretroCore*.swift`). dlopen + function pointers against
  the libretro buildbot dylibs; no full RetroArch runtime.
- **PPSSPP** is force-routed to the thick wrapper (`PVCoreFactory.swift`). Its GLES path spawns an emu thread + GPU-init pump whose GL-context/FBO ordering doesn't line up with the thin wrapper's deferred `context_reset`; thin still hangs on boot. `setupHardwareRenderCallback:` eagerly makes `_glContext` current (helps other HW cores) but that alone doesn't fix PPSSPP. Needs runtime trace of the boot hang to resolve thin.
- The thick RetroArch wrapper (`CoresRetro/RetroArch/PVRetroArchCore/`) is available as an opt-in escape hatch via `Defaults[.useLegacyRetroArchWrapper]` in Settings > Advanced.
- **Thin wrapper gaps:** deferred Vulkan context setup (GL is now eagerly activated; Vulkan still deferred). BIOS files synced from `BIOSPath` into system directory before `retro_load_game`. `ScalingMode` integration works (via `PVMetalViewController` + DeltaSkin skin container). Fast-forward wired (`setGameSpeed:` override syncs `_speedMultiplier` + `_audioPaused`).

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
- Emulator core submodules are in `Cores/<name>/<upstream-submodule-dir>` — avoid modifying third-party upstream source directly (exception: the RetroArch fork at `CoresRetro/RetroArch/RetroArch/` is maintained in-repo for Provenance)
- Each PV* module is a standalone Swift Package with its own `Package.swift`
- The top-level `Package.swift` is minimal (legacy SPM support for PVLibrary only); the real build system is the Xcode workspace
- Build variants (Lite/Standard/XL) differ in which cores are included; see `CoresRetro/RetroArch/Scripts/` for core lists per target

### Build & toolchain gotchas

- **RetroArch submodule edits need two commits.** The RA fork at `CoresRetro/RetroArch/RetroArch/` is a real git submodule. To ship a change: (1) `cd` into the submodule, commit on a `Provenance/<feature>` branch, push to the `Provenance` remote; (2) `cd` back to the parent, `git add CoresRetro/RetroArch/RetroArch && git commit` to bump the pointer. Skipping (2) leaves develop pointing at the old SHA.
- **PVRetroArch.xcodeproj is not file-system-synced for source files.** Only the `scripts/` folder is in a `PBXFileSystemSynchronizedRootGroup`. New `.mm`/`.m`/`.h` files under `CoresRetro/RetroArch/PVRetroArchCore/Core/` MUST be added explicitly to `project.pbxproj` in 4 spots: PBXBuildFile, PBXFileReference, group children, Sources build phase. Use `C0C0CAFE...`-prefixed UUIDs.
- **`gh issue list` has no `--sort` flag.** Use `gh issue list --search "sort:created-desc"` or `gh issue list --json number,title,createdAt --jq '.'` for sorted/filtered queries.

### Metal rendering gotchas

- **`CAMetalLayer.nextDrawable` blocks forever when backgrounded.** Metal reclaims drawables during background. The CA runloop observer fires `MTKView.draw(in:)` before `didBecomeActiveNotification`, so `currentDrawable` deadlocks the main thread. ALL `draw(in:)` implementations MUST early-return when `UIApplication.shared.applicationState != .active`.
- **`@synchronized(self)` in emulation loop vs main thread.** The emu loop holds `@synchronized(self)` around `executeFrame` at 60fps. Any main-thread code that acquires the same lock (e.g., `setPauseEmulation`) will starve. Set atomic flags BEFORE acquiring the lock so the emu loop sees the change and releases.
- **Thin wrapper reports its geometry/aspect/sample-rate LATE.** `PVThinLibretroFrontend` populates `_rawAVInfo` (geometry, aspect, `timing.sample_rate`, fps) only at the END of `startWithROMPath` — which runs inside `startEmulation`, NOT during `loadFile` (that only dlopens the core). But `createEmulator()` sets up the audio graph (`setupAudioGraph`/`startAudio`) AND the DeltaSkin viewport BEFORE `core.startEmulation()`. So anything that reads the core's geometry/aspect/sample-rate at view/audio-setup time gets the fallback defaults (`?: 640/480/256`, `audioSampleRate → 44100`), not the real values. Native/thick cores populate av_info during `loadFile`, so they don't hit this. This has caused: (1) thin-wrapper audio built at 44100 then never rebuilt → bassy/glitchy (fixed by rebuilding the audio graph after start if the rate changed, #cb40fef061); (2) skin render view stuck full-screen/wrong-size until rotation because the viewport was computed before geometry settled (fixed by recomputing on layout-settle, #a63e1622f1). Pattern for any new feature that reads core geometry/rate: recompute/refresh AFTER `startEmulation`, gated on the value actually having changed.

### Debugging emulator cores

- **flycast cannot be debugged with Xcode attached.** It installs `signal(SIGSEGV, ...)` for VRAM lazy-mapping; Xcode catches SIGSEGV and pauses, breaking the core. Use Console.app (filter `Process = Provenance`) for live logs OR `iOS Settings → Privacy & Security → Analytics → Analytics Data` for `.ips` crash files post-mortem.
- **Sentry's `enableCrashHandler` is disabled** at `SentryBootstrapTask.swift:48` because its SIGSEGV handler conflicts with flycast's MMU path. Do NOT re-enable it. Crash telemetry flows through MetricKit instead.
- **iPad MoltenVK surface_caps lie.** On iPadOS 26 with Stage Manager / adaptive scaling, `VkSurfaceCapabilitiesKHR.currentExtent` / `minImageExtent` / `maxImageExtent` ALL report `view.bounds × contentScaleFactor`, NOT the actual `CAMetalLayer.drawableSize`. They can differ (e.g. 2732×2048 vs 2092×1568). The authoritative source for iOS Vulkan is `metalLayer.drawableSize`. Never clamp against MoltenVK surface caps on iOS — see the iOS-gated branch in `gfx/common/vulkan_common.c::vulkan_create_swapchain`.
- **libretro core option key prefixes don't always match the core name.** flycast's options are `reicast_*` (per `CORE_OPTION_NAME` in `shell/libretro/libretro_core_option_defines.h`). Always grep the core's `libretro_core_options.h` before guessing key names.
- **Jaguar numpad uses keyboard input.** The upstream `virtualjaguar-libretro` core reads numpad buttons 0-9/*/# via `RETRO_DEVICE_KEYBOARD` (`RETROK_0`-`RETROK_9`, `RETROK_MINUS`, `RETROK_EQUALS`), NOT joypad buttons. Buttons 7-9/*/# have NO joypad mapping. The thin wrapper dispatches both keyboard events (via `_bridge.setKeyState`) and joypad presses for compatibility.

### Code conventions

- **Notification names — no magic strings.** Declare `FOUNDATION_EXPORT NSNotificationName const FooBarNotification;` in an ObjC `.h`, define in the matching `.mm`, mirror via `Notification.Name` extension in Swift referencing the same string. Posters reference the const; observers reference `Notification.Name.fooBar`. Single string literal lives in one `.mm` — never at a call site.
- **Email in public-facing files / comments:** use `git@joemattiello.com` (SECURITY.md, README, GitHub issue comments, anything that ships publicly).
- **ObjC categories in SwiftPM modules can be silently elided.** When a category is declared in a separate `.h` file referenced by a modulemap, Swift module synthesis may drop it entirely — no error, just "no member" at call sites. Workaround: declare methods in the main `@interface` block. Known to affect `(LightGun)` categories on PVStellaBridge and PVProSystemGameCore. Other categories (Cheats, Trackball) in the same files work fine — root cause unclear.

### Subagent worktree rules

- Subagents in `isolation: worktree` MUST stay on their own branch — never `git reset` / `rebase` / `push` / touch `develop`. Their commits get cherry-picked onto develop afterward.
- Always include "DO NOT git reset / rebase / push / touch develop" in subagent prompts. Without it, parallel agents have historically collided (one agent ran `git reset HEAD~1` and dropped another agent's commit).
- After an agent reports completion: cherry-pick from the agent's branch onto develop in the MAIN worktree's `Provenance/` directory. Shell can land in the agent's worktree if you're not careful — verify `pwd` and `git branch --show-current` before each cherry-pick.

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
- **GitHub workflow files** — `.github/workflows/*.yml` may be edited when fixing CI issues or optimizing builds. However, GitHub Actions bot PRs cannot push workflow changes (requires `workflows` permission) — if an agent PR needs to include workflow changes, note this in the PR description so a maintainer can push them manually.
- **Submodule source** — `Cores/<name>/<upstream-dir>/` contents are third-party upstream code (do not casually fork in place)
- **Generated files** — `Version.h`, `Version.swift`, files in `cmake/` build dirs
- **CodeSigning.xcconfig** — contains developer-specific credentials
- **project.pbxproj** — editing is permitted and sometimes required (e.g., adding new app targets). When you add a new target, use deterministic UUID prefixes (e.g. `C0C0CAFE...`) to make additions easy to identify. Use `PBXFileSystemSynchronizedRootGroup` for source directories (Xcode 16+). Prefer minimal diffs — only touch the sections that need changing.
- **RetroArch fork** — `CoresRetro/RetroArch/RetroArch/` is a Provenance-maintained submodule; changes for build integration or features are allowed with focused diffs

### Minimum Deployment Targets

Provenance ships for **iOS 17+ and tvOS 17+**. The PV* packages also declare **macOS 14+ and visionOS 1+** so keep code compiling for them with platform guards, but no Catalyst/native-mac/visionOS app target ships today (native macOS is planned — see the 2026-08-07 macOS strategy spec). All new code MUST be written against these minimum versions — do **not** add availability guards or fallbacks for APIs available since iOS 17 or earlier.

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

9. **Multi-platform compilation** — Provenance ships for **iOS and tvOS**; the PV* packages additionally declare **macOS and visionOS**, so guarded code must keep compiling for them. All new code MUST compile on all declared platforms. Agents must mentally verify every changed file compiles for at least iOS AND tvOS before creating a PR.

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
