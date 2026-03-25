# Provenance AI Reviewer — Project Context

This file is injected into every AI review session. Keep it concise.

---

## Module Dependency Tiers

Higher tiers may import lower tiers. **Never the reverse.**

| Tier | Modules |
|------|---------|
| 0 | PVObjCUtils, PVFeatureFlags, PVCheevos |
| 1 | PVLogging, PVPlists, PVHashing |
| 2 | PVSettings, PVPrimitives |
| 3 | PVSupport, PVAudio, PVCoreAudio |
| 4 | PVCoreBridge, PVEmulatorCore, PVShaders |
| 5 | PVCoreBridgeRetro, PVCoreLoader, PVLookup, PVLibrary, PVRealm |
| 6 | PVUI, App targets (Provenance, ProvenanceTV) |

---

## Critical Patterns & What To Check

### Realm Thread Safety (🔴 CRITICAL if violated)
- Realm objects are **thread-confined**. Never pass a live `Object` or `Results<T>`
  across thread/actor boundaries — this crashes at runtime.
- Safe cross-thread patterns: pass primary keys (String/Int) and re-fetch,
  or call `.freeze()` before crossing. Freeze objects are read-only.
- `Results<T>` must NOT be captured across `async`/`await` suspension points.
- Write transactions: always inside `try realm.write { }`. Check for
  `realm.isInWriteTransaction` before nesting.

### SwiftData / @Model (🔴 for iOS 17+ gated code)
- `ModelContext` is **NOT Sendable** — do not pass across actor boundaries.
- `ModelContext(ModelContainer)` is non-@MainActor in iOS 18 SDK; check for
  older availability guards if targeting iOS 17 minimum.
- `@Relationship` must specify `deleteRule` or it defaults to `.nullify`
  (orphans on delete).
- `@Attribute(.unique)` required on any field used as a primary key.
- Lazy sequences from `realm.objects(...).map(...)` must be materialized with
  `Array(...)` before crossing an actor hop.

### ObjC/C++ Emulator Bridges (🟠 MAJOR if unguarded)
- Files: `PV*CoreBridge+Controls.mm`, `PVLibRetroCore.m`
- Input event callbacks (touchBegan, handleMouseEvent) run on the UI/main thread.
- The libretro core polling (`getPointerState:`, `getInput:`) runs on the
  emulator thread.
- Any flag written from one thread and read from the other **must** be guarded
  with `@synchronized(self)`. Both the write AND the read side need the lock.
- GCController callbacks: run on main thread. Emulator: its own thread.

### Actor Isolation / async-await
- `@MainActor` annotated code must not be called from non-main actors without
  `await MainActor.run { }`.
- Custom actors (`public actor Foo`) cannot use non-Sendable types across their
  isolation boundary.
- `nonisolated(unsafe)` is valid for stored properties that are only mutated
  before concurrent access begins (e.g., during init).

### Public API Surface
- Only expose what callers outside the module actually need.
- Changing `internal` → `public` on Realm model properties is only acceptable
  when another module's migration code genuinely requires read access.
  Flag unnecessary `public` promotions.

### Netplay — `PVNetplayCapable` pattern (added in #3319)
- Any emulator core that supports netplay MUST conform to `PVNetplayCapable`
  (defined in `PVNetplay/Sources/PVNetplay/Protocols/PVNetplayCapable.swift`).
- ObjC-backed cores need `extension MyBridge: @unchecked Sendable {}` BEFORE
  the `PVNetplayCapable` conformance extension (Sendable is a protocol requirement).
- `PVEmulatorViewController.quit()` must call `PVNetplayManager.shared.setActiveBridge(nil)`
  when the core stops. Guard with `#if canImport(PVNetplay)`.
- New `PVNetplayCapable` conformances placed in Xcode-project targets need
  `PVNetplay` added to that target's SPM package dependencies in `project.pbxproj`.

### Module Boundaries
- Submodule upstream source (`Cores/<name>/<upstream-dir>/`) must **never** be
  modified. Flag immediately as 🔴 CRITICAL.
- `project.pbxproj` changes are always suspicious — flag if unnecessary.
- SPM `Package.swift` changes: verify dependency tiers not violated.

---

## What NOT to Flag (Avoid Noise)

- `force_cast` / `force_try` inside established patterns with clear invariants —
  these are warnings in SwiftLint, not errors. Only flag if in a critical
  execution path with real crash risk.
- Line length up to 200 chars — enforced by SwiftLint, only flag obvious
  readability issues over 200.
- Copilot/AI co-author lines in commits.
- `@available` annotations that already match the iOS 17/tvOS 17 targets.
- Comments explaining historical context or TODOs — not actionable unless wrong.

---

## Common Severity Guide

| Severity | Examples |
|----------|---------|
| 🔴 CRITICAL | Realm object crossing thread boundary, force-unwrap of nil-able, crash-able libretro pointer dereference, upstream submodule modification |
| 🟠 MAJOR | Unsynchronized flag read/write on different threads, ModelContext passed as Sendable, tier dependency violation, missing deleteRule on @Relationship |
| 🟡 MINOR | Unnecessary public exposure, misleading naming, missing availability guard |
| ⚪ NIT | Style-only, whitespace, trivial naming preference |

---

## New Patterns (March 2026)

### PVRumbleProtocol / Haptics
- `PVRumbleProtocol` in `PVCoreBridge/Features/` — cores that support rumble conform to this.
- `PVHapticsManager` manages device and controller haptics; guard tvOS paths with `#if !os(tvOS)`.
- Strong/weak motor intensity is `Float` in `[0.0, 1.0]` range.

### RetroAchievements (PVCheevos)
- `PVCheevosProtocol` — cores opt in by conforming; added stubs first, implementation later.
- `AchievementSessionManager` — actor-based; calls from emulator thread must use `await`.
- Never call cheevos APIs before ROM is loaded and core is running.

### Per-Game Core Options
- `valueForOption(_:forMD5:)` pattern — static-context reads use MD5 to scope to a game.
- `resetOptionsForGame(md5:)` and `resetAllOptions()` are the scoped reset helpers.
- Options stored in `UserDefaults` with key `"pvcore.<bundleIdentifier>.<optionKey>.<md5>"`.

### WhatsNew Release Notes (JSON-driven)
- Release notes live in `PVUI/Sources/PVSwiftUI/Resources/whats-new.json`.
- `WhatsNewLoader.loadAll(...)` in `PVSwiftUI` converts JSON → `[WhatsNew]` for WhatsNewKit.
- `ProvenanceApp` conformance calls `WhatsNewLoader.loadAll(...)` — no hardcoded entries.
- **Agents**: If the exact release version is confirmed, use it. If unconfirmed, derive the next
  logical version from the current top entry in `whats-new.json` (e.g., bump patch: `3.4.1` → `3.4.2`).
  Do **NOT** skip significant whats-new entries just because the exact version isn't pinned yet —
  merged features will be in the next release. Only skip trivial/internal changes.
- **Note**: A separate automation bot may eventually auto-generate `whats-new.json` from changelog
  fragments. Until that workflow exists, agents should write entries directly.
- Entries must be in **descending** version order (newest at top).

### Virtual Keyboard / Mouse
- `PVVirtualKeyboardView` — SwiftUI QWERTY overlay; shown via `supportsVirtualKeyboard` on core.
- `PVMouseCursorView` — pointer overlay for computer cores; activated by `supportsVirtualMouse`.
- Both use `@Environment(\.pvEmulatorCoordinator)` — don't access directly from core bridge.
- Platform-specific layouts (C64, ZX Spectrum, CPC) in `PVUI/Sources/PVSwiftUI/VirtualKeyboard/`.

### Gyro Mouse (`GyroMouseAdapter`)
- `GyroMouseAdapter` in `PVCoreBridge/Features/` — drives `MouseResponder.mouseMoved(atPoint:)` from `GCMotion.rotationRate` (DualSense / Switch Pro) or `CMMotionManager` IMU fallback.
- Settings keys live in `PVSettings.Defaults.Keys`: `gyroMouseEnabled`, `gyroMouseSensitivity`, `gyroMouseDeadZone`.
- Adapter is `@MainActor`-confined. GCController motion callbacks hop to the main actor via `Task { @MainActor ... }`; CoreMotion callbacks are already delivered on the main queue (via `to: .main`) so `MainActor.assumeIsolated` is used instead to avoid per-sample Task overhead.
- A `_sessionToken` (UInt64) is captured at callback-registration time and checked inside each Task/closure; stale deliveries from a previous `attach` session are silently dropped.
- Lifecycle: call `attach(to:)` when the core starts. Use `isEnabled = false` / `true` to temporarily suspend or resume input during short pauses (e.g., in-game pause menu) while preserving cursor/filter state; setting `isEnabled = false` also resets the dt timestamp so cursor doesn't jump on resume. Call `detach()` only for full teardown (game/core stop, system switch, or long-lived backgrounding) where resetting all state is desired.
- Signal chain: dead zone → exponential moving average (low-pass) → sensitivity × dt → clamp to [0,1].
- Platform guards: `#if canImport(CoreMotion)` wraps the IMU path (unavailable on tvOS); `#if canImport(GameController)` wraps the GCController path.
- Flag 🟠 MAJOR if the adapter's motion callback writes cursor state without proper `@MainActor` isolation (missing `Task { @MainActor ... }` hop for GCController handlers, or missing `MainActor.assumeIsolated` for already-main-queue CoreMotion handlers).

### Per-Game Mouse Detection (`MouseGameRegistry`)
- `MouseGameRegistry.shared` in `PVCoreBridge/Features/` — single source of truth for whether a game uses a mouse.
- Two-tier approach: **always-on** systems (DOS, Macintosh, AtariST…) always return `true`; **conditional** systems (SNES, Saturn, Dreamcast, PSX) require a game-level MD5 or title match.
- `gameSupportsMouse` on `PVThinLibretroCore` delegates to `MouseGameRegistry.shared.gameSupportsMouse(systemIdentifier:md5:title:)`.
- Per-game user override stored in UserDefaults with key `"MouseGameRegistry.mouseEnabled.<md5>"` — overrides ALL automatic detection.
- When reviewing new mouse game additions, verify the system is in `conditionalMouseSystems` (🔴 CRITICAL if a system that should be conditional is added to `alwaysMouseSystems`).
- `MouseGamesProvider` protocol — cores declare static mouse game lists; registered at startup via `registerProvider(_:)`.
- New mouse game databases go in `MouseGameRegistry.knownMouseGameMD5s` or `knownMouseGameTitlePatterns`; never hardcode mouse checks inline.

### JIT Capability Matrix
- **`PVPrimitives.PVJITRequirement`** — rich 4-case Swift enum (`.notSupported`,
  `.optional(fallback:)`, `.automaticWithFallback`, `.requiredOrCrash`).
  Used as `PVEmulatorCore.jitRequirement` open property; subclasses override.
- **`PVCoreBridge.PVJITPlistRequirement`** — simple 3-case plist-driven enum
  (`.notRequired`, `.optional`, `.required`). Parsed from `Core.plist` by
  `CoreLoader` and stored in `PVJITRequirementRegistry`. For startup-time fallback
  when a Swift subclass override is not available.
- **DO NOT** use the same name `PVJITRequirement` for both types — `PVEmulatorCore`
  does `@_exported import` of both modules; duplicate names cause compiler ambiguity.
- **CRITICAL for `.requiredOrCrash` cores** (Azahar, emuThree, Play!): the app layer MUST acquire JIT
  before launching. Skipping this check will crash the emulator.
- When adding a new core, always override `jitRequirement` in the `PVEmulatorCore` subclass.
  For plist-driven cores, also add a `PVJITRequirement` key to `Core.plist`.
- **`PVJITDisabledWithoutJIT`** — if a core is shipped `PVDisabled = true` solely because
  it crashes without JIT, also set `PVJITDisabledWithoutJIT = true`. The runtime (#2794) uses
  `CoreLoader.jitDisabledCoreIdentifiers()` to auto-enable these cores once JIT is acquired.
  Do NOT set this flag for cores disabled for reasons other than JIT (broken, unfinished, etc.).

### DS Dual-Screen Skins
- `supportsSkins` flag on native DS cores (`PVDesmume2015Core`, `PVMelonDSCore`).
- `DefaultDeltaSkin` layout handles dual-screen sizing independently.
- Touch routing: only works with native cores, not RetroArch-wrapped dylib cores.

### NSLock Pattern (Modern)
- Use `lock.withLock { }` (Swift 5.10+) instead of bare `.lock()` / `.unlock()`.
- Both read AND write sides of shared state must use the same lock object.
- For actor-isolated state, prefer actor isolation over NSLock.

### LibraryNavigator / LibraryAction (March 2026)
- `LibraryNavigator.shared` (`PVUIBase/Navigation/LibraryNavigator.swift`) is the single hub for
  library-level UI actions (search, console navigation, game deep links).
- **Do NOT** add new `onReceive(AppState.shared.$pendingSearchQuery)` calls to any view;
  use `onReceive(LibraryNavigator.shared.$pendingAction)` instead.
- Tab-switching views (ConsolesWrapperView, RetroMainView) check for `.search` and switch tabs
  but **must NOT** call `LibraryNavigator.shared.clearPendingAction()`.
- Content views (HomeView, RetroGameLibraryView) call `consumeSearch { ... }` which clears the action.
- Deep links: `provenance://screen/search?q=<query>` → `AppRoute.search(query:)` →
  `LibraryRouteProvider` → `LibraryNavigator.dispatch(.search(query:))`.
  `LibraryNavigator.routeProvider` is a static instance auto-registered with
  `NavigationRouter.shared` in `LibraryNavigator.init()`, and `NavigationRouter.shared.handle(url:)`
  is invoked in `ProvenanceApp.handle(appURL:)` for `provenance://screen/` URLs. No per-view
  registration is required.
- Future library actions: add a case to `LibraryAction`, a URL path to `AppRoute`, and a response in
  any interested view — no changes to `LibraryNavigator` core needed.

### CompanionControllerCapable (March 2026)
- `CompanionControllerCapable` in `PVCoreBridge/Features/CompanionControllerCapable.swift` — cores that accept a companion iPhone/iPad as a controller conform to this protocol.
- `CompanionButton`, `CompanionAxisID`, `CompanionInputEvent` live in **PVCoreBridge** (not PVUI) so Tier-4 core bridges can conform without importing PVUI.
- `CoreCompanionBridge` (private, PVUI) is the `CompanionSlotDelegate` that diffs `CompanionInputState` snapshots and calls `handleCompanionInput(_:forPlayer:)` on the core.
- `PVEmulatorViewController.presentCompanionController()` sets `session.activeSystemID` preferring `game?.systemIdentifier` and falling back to `core.systemIdentifier` so `CompanionLayoutFactory` selects the right overlay.
- Tear down: call `emulatorVC.tearDownCompanionSession()` when the emulator is dismissed.
- iOS & macCatalyst only: all companion UI wiring is guarded with iOS/macCatalyst-specific `#if` checks (not a generic `#if !os(tvOS)`).

### Analog Deadzone Coordination (March 2026)
- Universal deadzone is stored in `Defaults[.analogDeadzone]` (Float 0–0.5) via PVSettings.
- **On-screen analog sticks** (DeltaSkins): `DeltaSkinInputHandler.analogStickMoved` applies
  deadzone via `Float.applyingDeadzone(_:)` before dispatching to the core.
- **Physical controllers** (bridge files): use `PVApplyAnalogDeadzone(value)` for true analog cores,
  `PVAnalogDigitalThreshold(fallback)` for digital-conversion thresholds. Both are inlines in
  `PVCoreObjCBridge/PVControllerButtonUtils.h`.
- **No-double-apply rule**: each core uses MAX(hardcoded, universal) — never additively stacks.
  Cores that fully manage their own deadzone should conform to `CoreDeadzoneCapable` and return
  `coreHandlesDeadzone = true`; the mode picker in settings controls whether this is respected.
- `CoreDeadzoneMode` enum: `.auto` (respect CoreDeadzoneCapable), `.universal` (always apply),
  `.coreManaged` (never apply universal).

---

## Project Conventions

- **Swift**: 4-space indent, no indent for `case`, trailing commas in collections
- **Obj-C**: 4-space indent, `@synchronized(self)` for thread safety (not `os_unfair_lock`)
- **SwiftLint**: `.swiftlint.yml` at repo root — 200-char lines, force_cast=warning
- **Xcode**: 16.2 (`/Applications/Xcode_16.2.app`), iOS/tvOS 17+ deployment target
- **Platforms**: iOS + tvOS. Both must compile. Check `#if os(tvOS)` guards where needed.
- **Branches**: `agent/**` for agent work, `feature/**` for human features, PR to `develop`
- **Commit style**: conventional commits (`fix:`, `feat:`, `chore:`, `build:`, `refactor:`)

## Module Tier Updates (March 2026)

| Tier | Modules |
|------|---------|
| 0 | PVObjCUtils, PVFeatureFlags, PVCheevos |
| 1 | PVLogging, PVPlists, PVHashing |
| 2 | PVSettings, PVPrimitives |
| 3 | PVSupport, PVAudio, PVCoreAudio |
| 4 | PVCoreBridge, PVEmulatorCore, PVShaders |
| 5 | PVCoreBridgeRetro, PVCoreLoader, PVLookup, PVLibrary, PVRealm, PVPatching |
| 6 | PVUI (PVSwiftUI, PVUIBase, PVUI_IOS, PVUI_TV), App targets |

Note: `PVPatching` (new module for ROM patching/IPS/BPS) is Tier 5.
`PVCheevos` is Tier 0 (no dependencies on higher tiers).

## New Patterns (2026)

### PVNetplayCapable / Netplay Bridge Pattern
- `PVNetplayCapable` (in `PVNetplay`) — protocol any netplay-capable core conforms to.
- `PVRetroArchCoreBridge` conforms via `PVRetroArchCoreBridge+PVNetplayCapable.swift`; it is marked `@unchecked Sendable` because netplay-state mutation is serialised on the RetroArch run loop.
- `PVRetroArchCoreCore` forwards `PVNetplayCapable` calls to its underlying `_bridge`.
- `PVEmulatorViewController+Netplay.swift` registers/deregisters the bridge with `PVNetplayManager.shared` around `startEmulation`/`stopEmulation`.
- New cores that support netplay should conform to `PVNetplayCapable`; PVUI will auto-detect via `core as? any PVNetplayCapable`.
- **Dolphin** (`PVDolphinCore`) conforms via `PVDolphinCore+PVNetplayCapable.swift` (Swift) + `PVDolphinCore+Netplay.mm` (ObjC++ bridge). The C++ API calls are guarded with `#if __has_include("Core/NetPlayClient.h")` so the file compiles even when the `dolphin-ios` submodule is absent. When reviewing changes to the bridge, check that `NetTraversalConfig`, `NetPlayClient`, and `NetPlayServer` constructor signatures still match the dolphin-ios submodule revision.

### PVToast In-Game Notification System
- `PVToastManager.shared` (Tier 6, `PVUIBase`) is `@MainActor` — all calls must be on the main actor.
- `PVToastHostingController.install(in:position:)` is the canonical way to embed the overlay into any `UIViewController`.
- Do **not** use `StatusMessageManager` for in-game (emulator session) notifications; use `PVToastManager`.
- `StatusMessageManager` remains the correct choice for library-level (import, scan, sync) notifications shown outside the emulator.

---

## Platform Support (for Availability Guard checks)

| Platform | Minimum Version | Priority |
|----------|----------------|----------|
| iOS | 17.0 | Primary — always must compile |
| tvOS | 17.0 | Primary — always must compile |
| macOS | 14.0 (Catalyst/native) | Aspirational — guard with `#if os(macOS)` |
| watchOS | 10.0 | Aspirational — non-UI code only |
| visionOS | 1.0 | Aspirational — guard with `#if os(visionOS)` |
| Linux | (no version) | Unit tests only (Tier 0–2 modules) |

**When reviewing `@available` annotations**: verify they include BOTH `iOS X` AND `tvOS X`.
Missing `tvOS` in an `@available` guard is a 🟡 MINOR issue. Missing iOS is 🟠 MAJOR.

Tier 0–2 modules that use Darwin-only APIs without `#if canImport(Darwin)` guards
will fail Linux CI — flag as 🟡 MINOR if in a Tier 0–2 module, ⚪ NIT otherwise.

### WidgetKit Extension (ProvenanceWidgets)
- `Extensions/ProvenanceWidgets/` — new iOS-only WidgetKit extension (`#if os(iOS)` guards throughout).
- Widget data access uses `PVGameProxy` / `PVRecentGameProxy` — **local Realm proxy objects** that
  mirror the schema of `PVGame` / `PVRecentGame`. These exist so the extension does NOT link PVLibrary.
  When reviewing schema changes to `PVGame` or `PVRecentGame`, check that the proxy classes in
  `WidgetDataProvider.swift` are kept in sync (property names and `@Persisted` attributes must match).
- `WidgetDataProvider` opens Realm **read-only** with `readOnly: true` — never change to read-write.
- All widget views are stateless SwiftUI; data comes from `TimelineEntry` only — no `@StateObject` / `@ObservedObject`.
- `kSchemaVersion` in `WidgetDataProvider.swift` must stay in sync with `schemaVersion` in `RomDatabase.swift`.
- The extension target requires the `group.org.provenance-emu.provenance` App Group entitlement.
- After any game launch/end in the main app, call `WidgetCenter.shared.reloadAllTimelines()`.

### CompanionControllerCapable / Trackball Input Pattern (added in #3393)
- `CompanionControllerCapable` in `PVCoreBridge/Sources/PVCoreBridge/Features/CompanionControllerCapable.swift` — protocol cores adopt to receive Companion Controller axis/button events.
- `TrackballGameRegistry.shared` in `PVCoreBridge/Features/` — per-game trackball detection (mirrors `MouseGameRegistry` pattern); only Atari 2600 in `conditionalTrackballSystems`.
- `PVEmulatorViewController+CompanionController.swift` (PVUI Tier 6) — drives the core using `CompanionInputRouter.slotDelegate` state-diff callbacks; forwards button edge events and trackball deltas to the core whenever the router reports changes for the active slot.
- `CompanionLayoutID.atari2600Trackball` (defined in `CompanionControllerCapable.swift`) = `"com.provenance.atari2600.trackball"` — the ID returned by `PVStellaGameCore.preferredCompanionLayoutID` for trackball titles; `CompanionLayoutFactory` maps it to `TrackballLayout`. Use this constant — never inline the string.
- **Thread safety**: Stella bridge uses `@synchronized(self)` for `_pendingMouseDX/Y` and `_mouseButtonLeft` — both written from the main thread (companion events) and read from the emulation thread (`input_state_callback`).
- New trackball game additions: add MD5 hashes and title patterns to `TrackballGameRegistry.knownTrackballGameMD5s` / `knownTrackballGameTitlePatterns`. Never inline trackball checks in core code.

### Light Gun Crosshair Overlay Pattern (added in #3365)
- `LightGunCrosshairView` in `PVUI/Sources/PVUIBase/SwiftUI/DeltaSkins/Views/Components/LightGunCrosshairView.swift` — transparent SwiftUI overlay rendering a configurable crosshair (dot/crosshair/reticle/off) at the light-gun cursor position.
- Overlay is driven by `Notification.Name.lightGunCursorDidMove` posted from `GCMouseLightGunDriver._deliverPosition()`. `userInfo` keys: `LightGunCursorNotification.positionXKey` / `positionYKey` (NSNumber, normalised [0,1]) and `LightGunCursorNotification.isOffscreenKey` (Bool).
- `LightGunCursorNotification.swift` in `PVCoreBridge/Features/` — defines the notification name and userInfo key constants. Import `PVCoreBridge` to use them.
- `LightGunCrosshairStyle` enum in `PVSettings/Settings/Model/LightGunCrosshairStyle.swift` — persisted via `Defaults.Keys.lightGunCrosshairStyle` (default `.crosshair`).
- `EmulatorWithSkinView` gates the overlay on `coreSupportsLightGun` — a `@State` Bool set on `.onAppear` by casting `coreInstance` to `LightGunResponder`. The overlay has `.allowsHitTesting(false)` so it never intercepts touch input.
- **Do not** remove the `.allowsHitTesting(false)` modifier — without it the overlay will block all touch input to the game screen.

## GitHub Workflow Awareness

Reviewers should be aware of — but NOT flag as code issues — the following:
- `.changelog/<PR_NUMBER>.md` fragment files — expected, do not flag as noise.
  **Agents**: one fragment per PR, named after the CURRENT PR number only. Never create multiple
  fragments named after other PR numbers in a single PR — consolidate all changes into one file.
- `whats-new.json` entries with unconfirmed future versions — flag as 🟡 MINOR
- Project board updates (`https://github.com/orgs/Provenance-Emu/projects/1/views/1`) — check that significant PRs are on the board
- Epic/sub-task references — PRs for sub-tasks should reference parent epic with "Part of #N"
