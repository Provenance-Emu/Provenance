# macOS Strategy Phase 0 + 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute Phase 0 (kill dead Catalyst/mac debt) and Phase 1 (make "Designed for iPad" on Mac — and iPad-with-keyboard — feel intentional: keyboard-triggered controller UI, menu-bar commands, working ⌘L, pointer polish, remappable keyboard map) from `docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md`.

**Architecture:** No new targets. All Phase 1 work ships inside the existing iOS binary (which is what runs on Apple Silicon Macs via "Designed for iPad"). The controller-navigable `TVMediaMainView` already compiles on iOS; we make the hardware-keyboard bridge feed `GamepadManager` so keyboard-only desktops can drive it. Menu bar via SwiftUI `.commands` on the main `WindowGroup` (SwiftUI lifecycle app — no `UIMenuBuilder` needed).

**Tech Stack:** Swift/SwiftUI, GameController framework (`GCKeyboard`/`GCController`), Defaults (sindresorhus) via PVSettings, Xcode workspace build.

## Global Constraints

- Minimum targets: iOS 17+, tvOS 17+ — no availability guards for APIs older than that.
- Every changed file MUST compile for iOS AND tvOS (guard with `#if !os(tvOS)` etc. — see CLAUDE.md pitfall list: `DragGesture`, haptics, `.onHover`, `UIDevice.current.orientation` are not on tvOS).
- `@ObservedObject` for singletons, `@StateObject` only for view-owned objects.
- SwiftLint: 200-char lines; run `swiftlint lint --path <file>` on every changed Swift file.
- Conventional commits, subject < 72 chars.
- Notification names: existing code posts `NSNotification.Name("PVShowSettings")` as a raw string at call sites — match the existing idiom in PVSwiftUI (do not invent a new constants scheme in this plan; that refactor is out of scope).
- Verification build (used by several tasks):
  ```bash
  xcodebuild build -workspace Provenance.xcworkspace -scheme "Provenance-Lite (AppStore)" -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
  ```
  and the tvOS variant with `-destination "generic/platform=tvOS Simulator"`.
- Work on branch `feature/macos-desktop-polish` off `develop`. NEVER force-push, reset, or touch develop directly.

---

## Phase 0 — Hygiene

### Task 1: Turn off dead Catalyst config

**Files:**
- Modify: `Provenance.xcodeproj/project.pbxproj` (all `SUPPORTS_MACCATALYST` sites)

**Interfaces:**
- Consumes: nothing
- Produces: project state Phase 1+2 rely on — Catalyst is not a supported destination; "Designed for iPad" (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES`) is untouched and remains the Mac path.

Background: every app target sets `SUPPORTS_MACCATALYST = YES` but `SUPPORTED_PLATFORMS` omits `macosx`, and `PVMetalViewController.swift` cannot compile against the Catalyst SDK. The spec decision is to drop Catalyst, not fix it.

- [ ] **Step 1: Count current sites**

Run: `grep -c "SUPPORTS_MACCATALYST = YES;" Provenance.xcodeproj/project.pbxproj`
Expected: a positive number (~45). Record it.

- [ ] **Step 2: Flip to NO**

```bash
sed -i '' 's/SUPPORTS_MACCATALYST = YES;/SUPPORTS_MACCATALYST = NO;/g' Provenance.xcodeproj/project.pbxproj
```

- [ ] **Step 3: Verify project still parses**

Run: `xcodebuild -list -project Provenance.xcodeproj 2>&1 | head -40`
Expected: scheme/target list prints, no parse error. Also `grep -c "SUPPORTS_MACCATALYST = YES;" Provenance.xcodeproj/project.pbxproj` now prints `0`.

- [ ] **Step 4: Commit**

```bash
git add Provenance.xcodeproj/project.pbxproj
git commit -m "build: disable dead Mac Catalyst config (Designed-for-iPad is the Mac path)"
```

---

### Task 2: Delete the dead AppKit shim

**Files:**
- Delete: `PVUI/Sources/PVUIBase/AppKitWrapper.swift`

**Interfaces:**
- Consumes: nothing
- Produces: nothing (file is `#if !canImport(UIKit)` — never compiled on iOS/tvOS/Catalyst; it is vendored KSPlayer code defining `UIApplicationDelegate = NSApplicationDelegate` typealiases, `KSButton`, `KSSlider`, a stub `UIAlertController`, etc.)

- [ ] **Step 1: Verify nothing outside the file references its unique symbols**

Run: `rg -n "KSButton|KSSlider|KSSliderDelegate|AppKitWrapper" PVUI/Sources Provenance ProvenanceTV --type swift | grep -v "AppKitWrapper.swift"`
Expected: only hits (if any) inside other `#if os(macOS)`/`#if !canImport(UIKit)` blocks. If a hit is in unguarded code, STOP and report instead of deleting.

- [ ] **Step 2: Delete**

```bash
git rm PVUI/Sources/PVUIBase/AppKitWrapper.swift
```

- [ ] **Step 3: Compile check (fast, module-level)**

The shipping platforms never compiled this file, so the iOS build in Task 6 is the real gate. For a quick local sanity check that the deletion didn't orphan a reference in guarded code, run:
`rg -n "UIApplicationDelegate = NSApplicationDelegate|typealias UIWindow = NSWindow" PVUI/Sources`
Expected: no results.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: delete dead vendored AppKit shim (AppKitWrapper.swift)"
```

---

### Task 3: Fix the dead entitlements mapping in Build.xcconfig

**Files:**
- Modify: `Build.xcconfig:90`

**Interfaces:**
- Consumes: nothing
- Produces: a coherent `CODE_SIGN_ENTITLEMENTS_macosx` key that Phase 2's native mac target can rely on (native macOS `PLATFORM_NAME` is `macosx`).

Current line 90 is doubly dead: it references undefined `$(MACOS_CODE_SIGN_ENTITLEMENTS)` (the defined variable at line 86 is `MAC_CODE_SIGN_ENTITLEMENTS`) and uses key suffix `macos` which never matches `$(PLATFORM_NAME)`.

- [ ] **Step 1: Edit**

Replace (exact text at `Build.xcconfig:90`):
```
CODE_SIGN_ENTITLEMENTS_macos = $(MACOS_CODE_SIGN_ENTITLEMENTS)
```
with:
```
CODE_SIGN_ENTITLEMENTS_macosx = $(MAC_CODE_SIGN_ENTITLEMENTS)
```

- [ ] **Step 2: Verify no other references to the dead name**

Run: `rg -n "MACOS_CODE_SIGN_ENTITLEMENTS" .` (repo root, excluding .git)
Expected: no results.

- [ ] **Step 3: Commit**

```bash
git add Build.xcconfig
git commit -m "build: fix dead macOS entitlements mapping in Build.xcconfig"
```

---

### Task 4: Remove the unwired "Provenance VR" placeholder package

**Files:**
- Delete: `Provenance VR/` (entire directory — Reality Composer Pro placeholder, single commit `dbe2664019`, referenced by nothing)
- Modify: `.swiftlint.yml` (remove its excluded entry, around line 49)
- Modify: `.codiumignore` (remove its entry, around line 22)

**Interfaces:**
- Consumes: nothing
- Produces: nothing (no target, package, or workspace references it)

- [ ] **Step 1: Re-verify it is unreferenced**

Run: `rg -ln "Provenance VR|Provenance_VR|provenance_VRBundle" --hidden -g '!.git' -g '!Provenance VR/**' .`
Expected: only `.swiftlint.yml` and `.codiumignore`. Any other hit → STOP and report.

- [ ] **Step 2: Delete and clean ignore files**

```bash
git rm -r "Provenance VR"
```
Then edit `.swiftlint.yml` and `.codiumignore` to remove the `Provenance VR` lines (exact-match lines containing `Provenance VR`).

- [ ] **Step 3: Commit**

```bash
git add .swiftlint.yml .codiumignore
git commit -m "chore: remove unwired Provenance VR RealityComposer placeholder"
```

---

### Task 5: Reconcile platform-support claims in docs

**Files:**
- Modify: `CLAUDE.md` (three spots)
- Modify: `.github/copilot-instructions.md` (platform rows ~lines 182, 198-199)

**Interfaces:**
- Consumes: decisions from the spec
- Produces: docs that agents/contributors rely on; must keep the "guard your code for other platforms" rule (SPM packages still declare macOS/visionOS) while correcting the shipping claims.

- [ ] **Step 1: Edit CLAUDE.md — Prerequisites bullet**

Replace:
```
- Minimum targets: iOS 17+, tvOS 17+ mandatory, Linux, macOS, visionOS, watchOS equivalent release versions when applicable
```
with:
```
- Minimum targets: iOS 17+, tvOS 17+ mandatory. macOS today = "Designed for iPad" (the iOS binary on Apple Silicon); a native macOS target is planned (see docs/superpowers/specs/2026-08-07-macos-visionos-strategy-design.md). Mac Catalyst is NOT supported. visionOS/watchOS/Linux: SPM packages declare them — keep code compiling with guards, but no app ships for them.
```

- [ ] **Step 2: Edit CLAUDE.md — Minimum Deployment Targets section intro**

Replace:
```
Provenance targets **iOS 17+, tvOS 17+, macOS 14+ (Catalyst), visionOS 1+**. All new code MUST be written against these minimum versions — do **not** add availability guards or fallbacks for APIs available since iOS 17 or earlier.
```
with:
```
Provenance ships for **iOS 17+ and tvOS 17+**. The PV* packages also declare **macOS 14+ and visionOS 1+** so keep code compiling for them with platform guards, but no Catalyst/native-mac/visionOS app target ships today (native macOS is planned — see the 2026-08-07 macOS strategy spec). All new code MUST be written against these minimum versions — do **not** add availability guards or fallbacks for APIs available since iOS 17 or earlier.
```

- [ ] **Step 3: Edit CLAUDE.md — Multi-platform compilation item 9**

Replace:
```
9. **Multi-platform compilation** — Provenance builds for **iOS, tvOS, macOS (Catalyst), and visionOS**. All new code MUST compile on all platforms. Agents must mentally verify every changed file compiles for at least iOS AND tvOS before creating a PR.
```
with:
```
9. **Multi-platform compilation** — Provenance ships for **iOS and tvOS**; the PV* packages additionally declare **macOS and visionOS**, so guarded code must keep compiling for them. All new code MUST compile on all declared platforms. Agents must mentally verify every changed file compiles for at least iOS AND tvOS before creating a PR.
```

- [ ] **Step 4: Edit .github/copilot-instructions.md**

Run `rg -n "visionOS|Catalyst" .github/copilot-instructions.md` to locate the platform rows. Update the macOS row to say `Designed for iPad today; native target planned; Catalyst not supported` and the visionOS row to say `1.0 | Aspirational — package declarations + #if os(visionOS) guards only; no app target` (matching `.github/prompts/reviewer-context.md:338`, which is already correct — leave that file alone).

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md .github/copilot-instructions.md
git commit -m "docs: correct macOS/Catalyst/visionOS support claims"
```

---

### Task 6: Phase 0 verification builds

**Files:** none (verification only)

- [ ] **Step 1: iOS simulator build**

Run the iOS verification build from Global Constraints.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: tvOS simulator build**

Run the tvOS variant.
Expected: `** BUILD SUCCEEDED **`.

If either fails with an error implicating Tasks 1-4, fix within the offending task's scope and re-commit (`fix:` commit referencing the task).

---

## Phase 1 — Desktop polish (Designed-for-iPad)

### Task 7: Add the `controllerStyleNavigation` setting

**Files:**
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (in the `Defaults.Keys` extension containing `mainUIMode`, ~line 938)

**Interfaces:**
- Consumes: existing `Defaults.Keys` pattern
- Produces: `Defaults.Keys.controllerStyleNavigation: Key<Bool>` (default `false`) — read by Tasks 9 and 10.

- [ ] **Step 1: Add the key**

Directly below the `mainUIMode` `#if/#endif` block, add:

```swift
    /// When enabled, a connected hardware keyboard activates the controller-style
    /// (TV-media) navigation UI on iOS/macOS-Designed-for-iPad, even with no gamepad attached.
    static let controllerStyleNavigation = Key<Bool>("controllerStyleNavigation", default: false)
```

- [ ] **Step 2: Standalone module build (Tier 2)**

Run: `cd PVSettings && swift build && cd ..`
Expected: `Build complete!`

- [ ] **Step 3: Lint + commit**

```bash
swiftlint lint --path PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift
git add PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift
git commit -m "feat(settings): add controllerStyleNavigation default"
```

---

### Task 8: Make the hardware keyboard drive GamepadManager

**Files:**
- Modify: `PVUI/Sources/PVUIBase/GameControllerNavigation/GamepadManager.swift`
- Modify: `PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift` (the `GCKeyboard.createController()` extension, ~line 949)

**Interfaces:**
- Consumes: `PVControllerManager.shared.keyboardController: GCController?` (set on `GCKeyboardDidConnect`, same module)
- Produces: `GamepadManager.shared.isKeyboardConnected: Bool` (`@Published`), and GamepadManager's existing `eventPublisher` now emits navigation events for keyboard input — Task 9's UI gate and the TVMedia UI's existing subscribers rely on this.

Background (verified): the keyboard bridge creates a **virtual** controller via `GCController.withExtendedGamepad()`. Virtual controllers never appear in `GCController.controllers()` and never post `GCControllerDidConnect`, so `GamepadManager.isControllerConnected` stays `false`. Additionally, programmatic `setValue` on `GCControllerElement` does not fire element handlers — the bridge only manually invokes the profile-level `gamepad.valueChangedHandler` (see the comment at `PVControllerManager.swift:1005`), so GamepadManager's element-level handlers would never fire even if attached.

- [ ] **Step 1: Dispatch element handlers from the keyboard bridge**

In `GCKeyboard.createController()` (`PVControllerManager.swift`), the `keyChangedHandler` closure currently ends with:

```swift
            // the system does not call this handler in setValue, so call it with the dpad
            gamepad.valueChangedHandler?(gamepad, gamepad.dpad)
```

Immediately BEFORE that line, add change-diffed element-handler dispatch. Add this state capture just above the `keyboard.keyChangedHandler = ...` assignment (inside `createController()`, after `let gamepad = controller.extendedGamepad!`):

```swift
        // Previous values for diffing so element-level handlers (GamepadManager)
        // only fire on actual changes. setValue does not invoke handlers itself.
        var prevDpad: (x: Float, y: Float) = (0, 0)
        var prevButtons: [String: Bool] = [:]
```

Then inside `keyChangedHandler`, before the existing `gamepad.valueChangedHandler?` call, add:

```swift
            // Fire element-level handlers on change (GamepadManager navigation).
            if prevDpad.x != dpad_x || prevDpad.y != dpad_y {
                prevDpad = (dpad_x, dpad_y)
                gamepad.dpad.valueChangedHandler?(gamepad.dpad, dpad_x, dpad_y)
            }
            func dispatchButton(_ name: String, _ element: GCControllerButtonInput?, _ pressedNow: Bool) {
                guard let element, prevButtons[name] != pressedNow else { return }
                prevButtons[name] = pressedNow
                element.pressedChangedHandler?(element, pressedNow ? 1.0 : 0.0, pressedNow)
                element.valueChangedHandler?(element, pressedNow ? 1.0 : 0.0, pressedNow)
            }
            dispatchButton("a", gamepad.buttonA, isPressed(.spacebar) || isPressed(.returnOrEnter))
            dispatchButton("b", gamepad.buttonB, isPressed(.keyF) || isPressed(.escape))
            dispatchButton("menu", gamepad.buttonMenu, isPressed(.graveAccentAndTilde))
            dispatchButton("options", gamepad.buttonOptions, isPressed(.one) || isPressed(.keyU))
            dispatchButton("l1", gamepad.leftShoulder, isPressed(.tab) || isPressed(.capsLock))
            dispatchButton("r1", gamepad.rightShoulder, isPressed(.keyR))
            dispatchButton("l2", gamepad.leftTrigger, isPressed(.leftShift))
```

- [ ] **Step 2: Teach GamepadManager about the keyboard**

In `GamepadManager.swift`:

1. Add the published property below `hasPhysicalGamepad`:

```swift
    /// Whether a hardware keyboard is attached (GCKeyboard). Keyboard-only desktops
    /// (Mac "Designed for iPad", iPad with keyboard) use this to enable
    /// controller-style navigation without a physical gamepad.
    @Published public private(set) var isKeyboardConnected: Bool = false
```

2. In `init()`, after the `hasPhysicalGamepad` line, add:

```swift
        isKeyboardConnected = GCKeyboard.coalesced != nil
```

3. In `setupNotifications()`, before `observers.append(connectObserver)`, add:

```swift
        let keyboardConnectObserver = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardConnected = true
            // PVControllerManager creates the virtual keyboard controller from the same
            // notification; hop the run loop so it exists before we attach handlers.
            DispatchQueue.main.async { self?.connectKeyboardControllerIfAvailable() }
        }

        let keyboardDisconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isKeyboardConnected = GCKeyboard.coalesced != nil
        }
```

and append both to `observers`. Also call `connectKeyboardControllerIfAvailable()` at the end of `setupNotifications()` (covers a keyboard already attached at launch).

4. Add the method:

```swift
    /// Attach navigation handlers to PVControllerManager's virtual keyboard controller.
    /// Virtual controllers never post GCControllerDidConnect, so connectGamepad() misses them.
    private func connectKeyboardControllerIfAvailable() {
        guard let keyboardController = PVControllerManager.shared.keyboardController else { return }
        DLOG("[GamepadManager] Attaching navigation handlers to keyboard controller")
        setupBasicControls(keyboardController)
        setupMenuToggleHandlers(keyboardController)
    }
```

Note: `GamepadManager` and `PVControllerManager` are both in PVUIBase — no new import. `PVControllerManager.shared` is `@MainActor`; the observer closures run on `.main`, so if the compiler demands isolation, wrap the body in `MainActor.assumeIsolated { }`.

- [ ] **Step 3: Compile check for both platforms**

Run the iOS AND tvOS verification builds (Global Constraints).
Expected: both succeed. (GCKeyboard exists on tvOS 14+; no guards needed.)

- [ ] **Step 4: Lint + commit**

```bash
swiftlint lint --path PVUI/Sources/PVUIBase/GameControllerNavigation/GamepadManager.swift
swiftlint lint --path PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift
git add PVUI/Sources/PVUIBase/GameControllerNavigation/GamepadManager.swift PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift
git commit -m "feat(input): hardware keyboard drives GamepadManager navigation"
```

---

### Task 9: Keyboard-triggered TVMedia UI + settings toggle

**Files:**
- Modify: `PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift` — wait, this file lives in the app target: it is `Provenance/Main UI/` — **verify with** `rg --files -g 'MainView.swift' PVUI Provenance` and edit the one under `PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift` (that is the audited path; `shouldUseTVMediaUI` is at ~line 189).
- Modify: `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift` (Advanced tab section)

**Interfaces:**
- Consumes: `Defaults.Keys.controllerStyleNavigation` (Task 7), `GamepadManager.shared.isKeyboardConnected` (Task 8)
- Produces: user-visible behavior; no new API.

- [ ] **Step 1: Gate change in MainView**

Add `import PVSettings` to the imports if not already present (current imports: SwiftUI, PVLogging, PVLibrary, PVUIBase, PVSwiftUI, PVThemes — note if the file compiles without an explicit PVSettings import via `@_exported` leaks, still add it explicitly).

Inside the `#if os(iOS)` property block (below `@State private var disconnectTask`), add:

```swift
    @Default(.controllerStyleNavigation) private var controllerStyleNavigation
```

Replace `shouldUseTVMediaUI(isLandscape:)` (currently lines 189-195):

```swift
    private func shouldUseTVMediaUI(isLandscape: Bool) -> Bool {
        guard #available(iOS 18.0, *) else { return false }
        if isLandscape, gamepadManager.isControllerConnected { return true }
        // Keyboard-only desktops (Mac "Designed for iPad", iPad w/ keyboard): opt-in via
        // Settings > Advanced. No landscape requirement — desktop windows are arbitrary.
        if controllerStyleNavigation, gamepadManager.isKeyboardConnected { return true }
        return false
    }
```

`@Default` makes the view re-evaluate when the toggle changes; `gamepadManager` is already `@ObservedObject`, so `isKeyboardConnected` changes re-evaluate too. The existing `.onChange(of: rawUseTVMedia)` + `handleTVMediaChange` debounce handles transitions.

- [ ] **Step 2: Settings toggle (Advanced tab)**

In `SettingsSwiftUI.swift`, locate `struct AdvancedSection` (`rg -n "struct AdvancedSection" PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift`). Add to its property list:

```swift
    @Default(.controllerStyleNavigation) var controllerStyleNavigation
```

and as the first row inside its body's section content (match neighboring rows' style — the file's `ThemedToggle` idiom, e.g. line ~1565):

```swift
        #if !os(tvOS)
        ThemedToggle(isOn: $controllerStyleNavigation) {
            SettingsRow(title: "Controller-Style Navigation",
                        subtitle: "Use the TV-style, keyboard/controller-driven library UI when a hardware keyboard is connected.",
                        icon: .sfSymbol("keyboard"))
        }
        #endif
```

Check the exact row-label component used by the neighboring toggles in AdvancedSection (some sections use `SettingsRow(title:subtitle:icon:)`, verify with the adjacent code and copy that exact shape). tvOS guard: tvOS already defaults to the TVMedia UI, the toggle is meaningless there.

- [ ] **Step 3: Compile both platforms, lint**

Run iOS + tvOS verification builds. Expected: both succeed.

```bash
swiftlint lint --path "PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift"
swiftlint lint --path PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
```

- [ ] **Step 4: Commit**

```bash
git add "PVUI/Sources/PVSwiftUI/App Delegate/MainUI/MainView.swift" PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
git commit -m "feat(ui): keyboard-activated controller-style navigation (opt-in)"
```

---

### Task 10: Main-window menu commands + finish ⌘L Load State

**Files:**
- Modify: `Provenance/Main UI/ProvenanceApp.swift` (attach `.commands` to `WindowGroup(id: "main")`)
- Modify: `PVUI/Sources/PVSwiftUI/App Delegate/Scenes/EmulationScene/EmulatorScene.swift` (⌘L stub at ~line 106)

**Interfaces:**
- Consumes: `NSNotification.Name("PVShowSettings")` (observed by `PVRootViewController.swift:124` — existing idiom), `appState.emulationUIState.{emulator,currentGame}`, `PVEmulatorViewController.loadSaveState(_:) async -> Bool` (`PVEmulatorViewController+Saves.swift:53`)
- Produces: menu-bar items on Mac, key-command discoverability on iPad.

- [ ] **Step 1: Main window commands**

In `ProvenanceApp.swift`, after the `WindowGroup(id: "main") { ... }` closing brace (and after any existing modifiers on it — chain onto the WindowGroup), add:

```swift
#if !os(tvOS)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: NSNotification.Name("PVShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
#endif
```

Scope note: keep this minimal — Settings only. Import/Search menu items need wiring that differs per UI mode; they are follow-up work, not this task (YAGNI).

- [ ] **Step 2: Implement ⌘L in EmulatorScene**

Replace (exact current code at `EmulatorScene.swift:106-109`):

```swift
                Button("Load State") {
                    // Show load state UI
                }
                .keyboardShortcut("l", modifiers: .command)
```

with:

```swift
                Button("Load Last Save State") {
                    guard let emulator = appState.emulationUIState.emulator,
                          let game = appState.emulationUIState.currentGame else { return }
                    let liveGame = game.isFrozen ? game.thaw() : game
                    guard let state = liveGame?.saveStates
                        .sorted(byKeyPath: "date", ascending: false)
                        .first else { return }
                    Task { _ = await emulator.loadSaveState(state) }
                }
                .keyboardShortcut("l", modifiers: .command)
```

(Pattern mirrors `resolveSaveState(for:action:)`'s `.lastAnySave` branch in `PVAppDelegate+Open.swift:572`. `currentGame` may be frozen — thaw before the live Realm query, matching the codebase's freeze/thaw discipline.)

- [ ] **Step 3: Compile both platforms, lint**

Run iOS + tvOS verification builds (the `.commands` blocks are `#if !os(tvOS)`).

```bash
swiftlint lint --path "Provenance/Main UI/ProvenanceApp.swift"
swiftlint lint --path "PVUI/Sources/PVSwiftUI/App Delegate/Scenes/EmulationScene/EmulatorScene.swift"
```

- [ ] **Step 4: Commit**

```bash
git add "Provenance/Main UI/ProvenanceApp.swift" "PVUI/Sources/PVSwiftUI/App Delegate/Scenes/EmulationScene/EmulatorScene.swift"
git commit -m "feat(ui): main-window Settings command; implement Cmd+L load state"
```

---

### Task 11: Pointer hover polish on game tiles

**Files:**
- Modify: `PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift` (hover block at ~line 236)

**Interfaces:**
- Consumes: existing `.onHover` scale/glow animation in the cell
- Produces: system pointer shape lift on iPad/Mac pointer (cosmetic only).

- [ ] **Step 1: Add the pointer effect**

At `GameItemViewCell.swift:236` the cell already has an `.onHover { hovering in ... }` modifier (guarded — confirm whether the surrounding code is inside `#if !os(tvOS)`; `.onHover` doesn't exist on tvOS so it must be). Chain immediately before the `.onHover`:

```swift
                #if os(iOS)
                .hoverEffect(.lift)
                #endif
```

(`.hoverEffect` is iOS-only; `#if os(iOS)` keeps tvOS/macOS-SPM compiles green.)

- [ ] **Step 2: Compile both platforms, lint, commit**

Run iOS + tvOS verification builds.

```bash
swiftlint lint --path PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift
git add PVUI/Sources/PVUIBase/SwiftUI/GameItem/GameItemViewCell.swift
git commit -m "feat(ui): pointer lift effect on game tiles"
```

---

### Task 12: Remappable keyboard→controller map (model + wiring)

**Files:**
- Create: `PVUI/Sources/PVUIBase/Controller/KeyboardControllerMap.swift`
- Modify: `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (storage key)
- Modify: `PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift` (`GCKeyboard.createController()` reads the map)

**Interfaces:**
- Consumes: Defaults storage
- Produces:
  - `public enum KeyboardControllerAction: String, CaseIterable, Codable` — cases: `dpadUp, dpadDown, dpadLeft, dpadRight, leftStickUp, leftStickDown, leftStickLeft, leftStickRight, rightStickUp, rightStickDown, rightStickLeft, rightStickRight, buttonA, buttonB, buttonX, buttonY, l1, l2, r1, r2, l3, r3, menu, options, select, start` (each with `public var displayName: String`)
  - `public struct KeyboardControllerMap` — `public static var current: KeyboardControllerMap`, `public static let standard: KeyboardControllerMap`, `public func keys(for action: KeyboardControllerAction) -> [GCKeyCode]`, `public mutating func set(keys: [GCKeyCode], for action: KeyboardControllerAction)`, `public func save()`
  - Task 13's UI uses exactly these names.

- [ ] **Step 1: Storage key in PVSettings**

Below `controllerStyleNavigation` (Task 7), add:

```swift
    /// Keyboard→virtual-controller bindings, action rawValue → GCKeyCode rawValues.
    /// Empty dict means "use the built-in standard map".
    static let keyboardControllerBindings = Key<[String: [Int]]>("keyboardControllerBindings", default: [:])
```

Run `cd PVSettings && swift build && cd ..` — expected: `Build complete!`

- [ ] **Step 2: Write the map type**

Create `PVUI/Sources/PVUIBase/Controller/KeyboardControllerMap.swift`:

```swift
import Foundation
import GameController
import PVSettings
import Defaults

/// A remappable action on the virtual keyboard-controller.
public enum KeyboardControllerAction: String, CaseIterable, Codable {
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight
    case buttonA, buttonB, buttonX, buttonY
    case l1, l2, r1, r2, l3, r3
    case menu, options, select, start

    public var displayName: String {
        switch self {
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .leftStickUp: return "Left Stick Up"
        case .leftStickDown: return "Left Stick Down"
        case .leftStickLeft: return "Left Stick Left"
        case .leftStickRight: return "Left Stick Right"
        case .rightStickUp: return "Right Stick Up"
        case .rightStickDown: return "Right Stick Down"
        case .rightStickLeft: return "Right Stick Left"
        case .rightStickRight: return "Right Stick Right"
        case .buttonA: return "A"
        case .buttonB: return "B"
        case .buttonX: return "X"
        case .buttonY: return "Y"
        case .l1: return "L1"
        case .l2: return "L2"
        case .r1: return "R1"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .menu: return "Menu"
        case .options: return "Options"
        case .select: return "Select"
        case .start: return "Start"
        }
    }
}

/// Keyboard→controller bindings, persisted to Defaults. Falls back to `standard`
/// (the historical hardcoded map) for any action with no stored binding.
public struct KeyboardControllerMap {
    private var bindings: [KeyboardControllerAction: [GCKeyCode]]

    /// The historical hardcoded layout (see the ASCII art above GCKeyboard.createController()).
    public static let standard = KeyboardControllerMap(bindings: [
        .dpadUp: [.upArrow], .dpadDown: [.downArrow], .dpadLeft: [.leftArrow], .dpadRight: [.rightArrow],
        .leftStickUp: [.keyW], .leftStickDown: [.keyS], .leftStickLeft: [.keyA], .leftStickRight: [.keyD],
        .rightStickUp: [.equalSign, .keyO], .rightStickDown: [.hyphen, .keyL],
        .rightStickLeft: [.openBracket, .keyK], .rightStickRight: [.closeBracket, .semicolon],
        .buttonA: [.spacebar, .returnOrEnter], .buttonB: [.keyF, .escape],
        .buttonX: [.keyQ], .buttonY: [.keyE],
        .l1: [.tab, .capsLock], .l2: [.leftShift],
        .r1: [.keyR], .r2: [.keyV],
        .l3: [.keyX], .r3: [.keyC],
        .menu: [.graveAccentAndTilde], .options: [.one, .keyU],
        .select: [.slash], .start: [.rightShift],
    ])

    public init(bindings: [KeyboardControllerAction: [GCKeyCode]]) {
        self.bindings = bindings
    }

    /// The effective map: stored overrides merged over `standard`.
    public static var current: KeyboardControllerMap {
        let stored = Defaults[.keyboardControllerBindings]
        guard !stored.isEmpty else { return .standard }
        var merged = standard.bindings
        for (raw, codes) in stored {
            guard let action = KeyboardControllerAction(rawValue: raw) else { continue }
            merged[action] = codes.map { GCKeyCode(rawValue: CFIndex($0)) }
        }
        return KeyboardControllerMap(bindings: merged)
    }

    public func keys(for action: KeyboardControllerAction) -> [GCKeyCode] {
        bindings[action] ?? []
    }

    public mutating func set(keys: [GCKeyCode], for action: KeyboardControllerAction) {
        bindings[action] = keys
    }

    /// Persist only the diff vs `standard` (so future default-map improvements reach users).
    public func save() {
        var diff: [String: [Int]] = [:]
        for (action, codes) in bindings where Self.standard.bindings[action] != codes {
            diff[action.rawValue] = codes.map { Int($0.rawValue) }
        }
        Defaults[.keyboardControllerBindings] = diff
    }
}
```

(Verify `GCKeyCode.rawValue` is `CFIndex`; if the initializer differs, adapt the two conversion sites — that is the only place raw values cross.)

- [ ] **Step 3: Consume the map in the keyboard bridge**

In `GCKeyboard.createController()` (`PVControllerManager.swift`), at the top of the `keyChangedHandler` closure, after the `isPressed` helper, add:

```swift
            let map = KeyboardControllerMap.current
            func actionPressed(_ action: KeyboardControllerAction) -> Bool {
                map.keys(for: action).contains { isPressed($0) }
            }
```

Then replace every hardcoded `isPressed(...)` composite with the action equivalent, preserving structure. Exact replacements:

- `let dpad_x:Float = isPressed(.rightArrow) ? 1.0 : isPressed(.leftArrow) ? -1.0 : 0.0` → `let dpad_x: Float = actionPressed(.dpadRight) ? 1.0 : actionPressed(.dpadLeft) ? -1.0 : 0.0`
- `let dpad_y:Float = ...` → same pattern with `.dpadUp` / `.dpadDown`
- left stick x/y → `.leftStickRight/.leftStickLeft` and `.leftStickUp/.leftStickDown`
- right stick x/y → `.rightStickRight/.rightStickLeft` and `.rightStickUp/.rightStickDown`
- `gamepad.buttonA.setValue(... .spacebar ... .returnOrEnter ...)` → `gamepad.buttonA.setValue(actionPressed(.buttonA) ? 1.0 : 0.0)` — and likewise buttonB→`.buttonB`, buttonX→`.buttonX`, buttonY→`.buttonY`, leftShoulder→`.l1`, leftTrigger→`.l2`, rightShoulder→`.r1`, rightTrigger→`.r2`, buttonMenu→`.menu`, buttonOptions→`.options`, leftThumbstickButton→`.l3`, rightThumbstickButton→`.r3`
- In the select/start block at the bottom: `isPressed(.slash)` → `actionPressed(.select)`, `isPressed(.rightShift)` → `actionPressed(.start)`
- Update Task 8's `dispatchButton` call sites to use `actionPressed(.buttonA)` etc. instead of repeated `isPressed` composites.

Keep the ASCII-art comment above the extension but add a line: `// Defaults are defined in KeyboardControllerMap.standard; users can remap in Settings.`

- [ ] **Step 4: Compile both platforms, lint**

Run iOS + tvOS verification builds. Expected: both succeed.

```bash
swiftlint lint --path PVUI/Sources/PVUIBase/Controller/KeyboardControllerMap.swift
swiftlint lint --path PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift
```

- [ ] **Step 5: Commit**

```bash
git add PVUI/Sources/PVUIBase/Controller/KeyboardControllerMap.swift PVUI/Sources/PVUIBase/Controller/PVControllerManager.swift PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift
git commit -m "feat(input): remappable keyboard-to-controller map (model + bridge)"
```

---

### Task 13: Keyboard mapping settings UI

**Files:**
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/KeyboardMappingView.swift`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift` (link from the Controller tab's `ControllerSection`)

**Interfaces:**
- Consumes: `KeyboardControllerAction` / `KeyboardControllerMap` exactly as produced by Task 12; `PVControllerManager.shared.handleKeyboardConnect(nil)` / `handleKeyboardDisconnect(nil)` (both `@objc @MainActor`, callable directly) to rebuild the virtual controller after saving.
- Produces: `KeyboardMappingView` (public SwiftUI view).

- [ ] **Step 1: Write the view**

Create `KeyboardMappingView.swift`:

```swift
import SwiftUI
import GameController
import PVUIBase
import PVThemes

/// Lists every keyboard-controller action with its bound keys; tap a row then press
/// a key to rebind. iOS/Catalyst-style desktop feature; excluded from tvOS.
#if !os(tvOS)
public struct KeyboardMappingView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var map = KeyboardControllerMap.current
    @State private var capturingAction: KeyboardControllerAction?
    @State private var savedKeyHandler: GCKeyboardValueChangedHandler?

    public init() {}

    public var body: some View {
        List {
            SwiftUI.Section(footer: Text("Tap an action, then press a key to rebind. Press Delete to clear back to default.")) {
                ForEach(KeyboardControllerAction.allCases, id: \.rawValue) { action in
                    Button {
                        beginCapture(for: action)
                    } label: {
                        HStack {
                            Text(action.displayName)
                            Spacer()
                            Text(capturingAction == action ? "Press a key…" : keyNames(for: action))
                                .foregroundColor(capturingAction == action
                                                 ? themeManager.currentPalette.defaultTintColor?.swiftUIColor ?? .accentColor
                                                 : .secondary)
                        }
                    }
                }
            }
            SwiftUI.Section {
                Button("Reset All to Defaults", role: .destructive) {
                    map = .standard
                    map.save()
                    rebuildKeyboardController()
                }
            }
        }
        .navigationTitle("Keyboard Mapping")
        .onDisappear { endCapture() }
    }

    private func keyNames(for action: KeyboardControllerAction) -> String {
        let keys = map.keys(for: action)
        guard !keys.isEmpty else { return "—" }
        return keys.map { keyName($0) }.joined(separator: ", ")
    }

    private func keyName(_ code: GCKeyCode) -> String {
        // GCKeyboardInput buttons carry readable names via their sfSymbolsName/localizedName.
        if let button = GCKeyboard.coalesced?.keyboardInput?.button(forKeyCode: code),
           let name = button.aliases.first ?? button.localizedName {
            return name
        }
        return "Key \(code.rawValue)"
    }

    private func beginCapture(for action: KeyboardControllerAction) {
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else { return }
        endCapture()
        capturingAction = action
        savedKeyHandler = keyboardInput.keyChangedHandler
        keyboardInput.keyChangedHandler = { _, _, keyCode, pressed in
            guard pressed else { return }
            DispatchQueue.main.async {
                if keyCode == .deleteOrBackspace {
                    map.set(keys: KeyboardControllerMap.standard.keys(for: action), for: action)
                } else {
                    map.set(keys: [keyCode], for: action)
                }
                map.save()
                endCapture()
                rebuildKeyboardController()
            }
        }
    }

    private func endCapture() {
        if let saved = savedKeyHandler {
            GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = saved
            savedKeyHandler = nil
        }
        capturingAction = nil
    }

    /// Recreate the virtual keyboard controller so the new bindings take effect.
    private func rebuildKeyboardController() {
        PVControllerManager.shared.handleKeyboardDisconnect(nil)
        PVControllerManager.shared.handleKeyboardConnect(nil)
    }
}
#endif
```

Implementation notes for the engineer:
- `GCKeyboardValueChangedHandler` is the typealias for `keyChangedHandler`'s closure type; if the SDK name differs, use the closure type spelled out (`(GCKeyboardInput, GCControllerButtonInput, GCKeyCode, Bool) -> Void`).
- `button.aliases.first ?? button.localizedName` — check the real `GCControllerButtonInput` API surface; if `aliases` isn't available, use `localizedName` alone with the `"Key N"` fallback.
- `SwiftUI.Section` must be fully qualified in PVUI (QuickTable's `Section` class shadows it — known project gotcha).
- Capturing steals `keyChangedHandler` from the virtual controller bridge; `endCapture()` restores it on every exit path (including `.onDisappear`).

- [ ] **Step 2: Link from Controller settings**

In `SettingsSwiftUI.swift`, locate `ControllerSection` (`rg -n "struct ControllerSection" PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift`, ~line 1950) and add a navigation row after the existing rows, matching the section's NavigationLink idiom:

```swift
        #if !os(tvOS)
        NavigationLink(destination: KeyboardMappingView()) {
            SettingsRow(title: "Keyboard Mapping",
                        subtitle: "Remap keyboard keys to controller buttons.",
                        icon: .sfSymbol("keyboard.badge.ellipsis"))
        }
        #endif
```

(Copy the exact row/label component the neighboring rows in `ControllerSection` use — same rule as Task 9 Step 2.)

- [ ] **Step 3: Compile both platforms, lint**

Run iOS + tvOS verification builds. Expected: both succeed (view is `#if !os(tvOS)`).

```bash
swiftlint lint --path PVUI/Sources/PVSwiftUI/Settings/Views/KeyboardMappingView.swift
swiftlint lint --path PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
```

- [ ] **Step 4: Commit**

```bash
git add PVUI/Sources/PVSwiftUI/Settings/Views/KeyboardMappingView.swift PVUI/Sources/PVSwiftUI/Settings/SettingsSwiftUI.swift
git commit -m "feat(settings): keyboard mapping remap UI"
```

---

### Task 14: End-to-end verification + smoke checklist

**Files:** none

- [ ] **Step 1: Full builds** — iOS and tvOS verification builds green on the branch tip.

- [ ] **Step 2: Manual smoke checklist** (needs a human or simulator session; record results, do not skip silently):
  1. iPad simulator, hardware-keyboard capture ON: toggle Settings > Advanced > Controller-Style Navigation → TVMedia UI appears; arrows/space navigate it.
  2. Toggle OFF → returns to paged UI (450 ms debounce).
  3. In-game: ⌘S saves, ⌘L loads the newest save, ⌘P pauses, ⇧⌘Q quits.
  4. Main window: ⌘, opens Settings.
  5. Settings > Controller > Keyboard Mapping: rebind A to a letter key, verify in-game; Reset All restores.
  6. tvOS simulator: settings screens unaffected (no new rows visible), library navigates normally.

- [ ] **Step 3: Report** — summarize commits, any deviations, and smoke results. PR (if requested) targets `develop` with `[Agent]` prefix per CLAUDE.md.

---

## Deliberately deferred (tracked, not forgotten)

1. **`ThumbnailExtensionMacOS` / DriverKit target removal** (spec Phase 0): deleting pbxproj
   targets is higher-risk surgery than the payoff warrants right now, and Phase 2's native mac
   app may become their host. Deferred to Phase 2 planning.
2. **Find/Sort/Import menu commands** (spec Phase 1 item 3 beyond Settings + ⌘L): their wiring
   differs per `MainUIMode` (LibraryNavigator vs paged vs TVMedia) and needs its own small
   investigation. Follow-up task after the smoke test proves the `.commands` plumbing.
