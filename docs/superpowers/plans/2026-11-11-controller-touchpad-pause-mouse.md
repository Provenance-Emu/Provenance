# Controller touchpad: test screen, pause and mouse (steps 0-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A PS4/PS5 pad's touchpad click opens the pause menu, Create is Select on every core, and the touchpad is a correct, adjustable mouse for every mouse-capable core, with a test screen to check the hardware.

**Architecture:** Pure, `Sendable` decision logic in PVCoreBridge (`Features/ControllerPointer/`) turns touchpad samples into pointer outputs. A small `@MainActor` router in PVUIBase samples the pad on a display link and hands those outputs to the running core. Nothing installs a handler on a controller element.

**Tech Stack:** Swift 5/6, GameController, SwiftUI, Defaults, XCTest (PVCoreBridge), Swift Testing (PVUI, PVLibRetro), Objective-C++ core bridges.

**Spec:** `docs/superpowers/specs/2026-11-11-controller-touchpad-gyro-design.md` (steps 0, 1 and 2). Steps 3-7 (Wii pointer, Wii shake and tilt, light gun, gyro aiming, GameCube triggers) get a second plan after the step 0 screen has been run on a device.

## Global Constraints

- iOS 17+ and tvOS 17+; every file compiles for both.
- `SystemIdentifier`, never raw system strings.
- No new `valueChangedHandler` or `pressedChangedHandler` on a controller element; sample state.
- A press that reaches the game never also opens the menu, and the reverse.
- The cursor never jumps when a finger lands or lifts.
- Decision logic is pure, in PVCoreBridge, and unit tested there.
- Shared checkout: commit only this plan's files, by path. Running `xcodebuild` in a package rewrites its `Package.resolved`; restore it by path afterwards.
- Test commands. PVCoreBridge: `cd PVCoreBridge && xcodebuild test -scheme PVCoreBridge-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' EXCLUDED_ARCHS=x86_64 CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation -only-testing:PVCoreBridgeTests/<Class>`. PVUI: the `PVUI-UnitTests` scheme with the realm-core `-xcconfig` (CLAUDE.md), `-only-testing:PVUIBaseTests/<SuiteStructName>`; run once per batch, not per task.

## Review Focus

1. A finger resting exactly on the pad's centre reads (0, 0), the same as a lifted finger. Expected: no cursor jump before or after. Test in Task 1 (`testCentreCrossingProducesNoJump`).
2. The pad disconnects, or the role changes, while a click is held. Expected: the held button is released once. Test in Task 2 (`testResetReleasesHeldActions`).
3. The pause menu opens while a finger is down or a click is held. Expected: nothing is delivered while suspended and no stale delta or click fires on resume. Test in Task 2 (`testSuspendDropsStateWithoutEvents`).
4. The player remaps the touchpad click while a game runs. Expected: the click stops opening the menu at once. Test in Task 4 (`touchpadTriggerLeavesWhenNotFree`).
5. A two-finger click with the fingers still sliding. Expected: one right-click (or the bound action), no speed change, no recenter. Test in Task 1 (`testTwoFingerClickCancelsSlideAndTap`).

---

### Task 1: Touchpad sample and gesture recognizer

**Files:**
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/TouchpadSample.swift`
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/TouchpadGestureRecognizer.swift`
- Test: `PVCoreBridge/Tests/PVCoreBridgeTests/TouchpadGestureRecognizerTests.swift`

**Interfaces (produces):**

```swift
public struct TouchpadPoint: Equatable, Sendable { public var x: Float; public var y: Float }   // pad units -1...1, +y up
public struct TouchpadSample: Equatable, Sendable {
    public var primary: TouchpadPoint?      // nil = finger up
    public var secondary: TouchpadPoint?
    public var isClicked: Bool
    public init(primary: TouchpadPoint?, secondary: TouchpadPoint?, isClicked: Bool)
    /// Raw axis values; a finger at exactly (0, 0) is "up".
    public init(primaryX: Float, primaryY: Float, secondaryX: Float, secondaryY: Float, isClicked: Bool)
}
public enum TouchpadClickZone: String, Codable, Sendable, CaseIterable { case left, right, twoFinger }
public enum TouchpadEvent: Equatable, Sendable {
    case touchBegan, touchEnded
    case moved(dx: Float, dy: Float)        // pad units, +dy = down the screen
    case clickDown(TouchpadClickZone), clickUp(TouchpadClickZone)
    case twoFingerTap
    case twoFingerSlide(steps: Int)         // positive = fingers moved up
}
public struct TouchpadGestureRecognizer: Sendable {
    public struct Tuning: Equatable, Sendable {
        public var tapMaxDuration: TimeInterval = 0.25
        public var tapMaxTravel: Float = 0.15
        public var slideStepTravel: Float = 0.3
        public init()
    }
    public init(tuning: Tuning = Tuning())
    public mutating func update(_ sample: TouchpadSample, at time: TimeInterval) -> [TouchpadEvent]
    public mutating func reset()            // forget everything, emit nothing
}
```

Rules the tests pin: the first sample after a finger lands emits `touchBegan` and no `moved`; a lift emits `touchEnded` and no `moved`; while two fingers are down no `moved` is emitted; click zone is `twoFinger` with two fingers down, else `left` for `primary.x < 0` or no finger, else `right`; `clickUp` carries the zone its `clickDown` had; a click with two fingers down cancels the tap and the slide in progress; a slide counts only vertical travel of the two fingers' mean, one step per `slideStepTravel`; a tap needs both fingers down then up within `tapMaxDuration` and under `tapMaxTravel`.

- [ ] **Step 1:** Write `TouchpadGestureRecognizerTests` (XCTest) with: `testRawZeroIsFingerUp`, `testFirstSampleAfterLandingHasNoDelta`, `testDragEmitsDeltaWithScreenY` (pad +y up becomes `dy < 0`), `testLiftEmitsNoDelta`, `testCentreCrossingProducesNoJump` (samples (-0.1,0.2) → (0,0) → (0.1,0.2): no `moved` larger than 0 across the gap), `testClickZones`, `testClickUpKeepsDownZone`, `testTwoFingersFreezeMovement`, `testTwoFingerTap`, `testSlowTwoFingerLiftIsNotATap`, `testTwoFingerSlideSteps` (travel 0.65 up = 2 steps), `testTwoFingerClickCancelsSlideAndTap`, `testResetEmitsNothing`.
- [ ] **Step 2:** Run the class; expect compile failure (types missing).
- [ ] **Step 3:** Implement both files.
- [ ] **Step 4:** Run the class; expect all pass.
- [ ] **Step 5:** Commit `feat(input): touchpad sample and gesture recognizer`.

### Task 2: Speed curve, cursor, role policy, bindings and the pointer session

**Files:**
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/PointerCursor.swift` (also `PointerSpeedCurve`)
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/ControllerPointerRole.swift` (role, mode, context, policy, `PointerAction`, `PointerClickBindings`)
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/ControllerPointerSession.swift`
- Test: `PVCoreBridge/Tests/PVCoreBridgeTests/ControllerPointerSessionTests.swift`, `ControllerPointerPolicyTests.swift`

**Interfaces (consumes Task 1; produces):**

```swift
public struct PointerSpeedCurve: Equatable, Sendable {
    public static let speedRange: ClosedRange<Double> = 0.1...5.0
    public var speed: Double            // 1.0: a full pad sweep (2 pad units) crosses the screen once
    public var acceleration: Double     // 0...1
    public init(speed: Double = 1.0, acceleration: Double = 0.3)
    public func screenDelta(padDX: Double, padDY: Double, dt: TimeInterval) -> (dx: Double, dy: Double)
}
public struct PointerCursor: Equatable, Sendable {
    public private(set) var position: CGPoint                    // 0...1, origin top-left
    public init(position: CGPoint = CGPoint(x: 0.5, y: 0.5))
    public mutating func apply(dx: Double, dy: Double) -> CGPoint   // the delta actually applied after clamping
    public mutating func set(_ position: CGPoint)
    public mutating func recenter()
}
public enum ControllerPointerRole: String, Codable, Sendable { case none, mouse, wiiPointer, lightGun }
public enum ControllerPointerMode: String, Codable, Sendable, CaseIterable { case automatic, off, mouse, wiiPointer, lightGun }
public struct ControllerPointerContext: Equatable, Sendable {
    public var system: SystemIdentifier?
    public var gameSupportsMouse, gameSupportsLightGun, coreSupportsPointer, padHasPointerInput: Bool
    public init(system:gameSupportsMouse:gameSupportsLightGun:coreSupportsPointer:padHasPointerInput:)
}
public enum ControllerPointerPolicy {
    public static func role(for context: ControllerPointerContext, mode: ControllerPointerMode) -> ControllerPointerRole
}
public enum PointerAction: String, Codable, Sendable, CaseIterable {
    case leftButton, rightButton, trigger, reload, auxA, auxB, gunStart, wiiA, wiiB, pauseMenu, none
}
public struct PointerClickBindings: Codable, Equatable, Sendable {
    public subscript(zone: TouchpadClickZone) -> PointerAction { get set }
    public static func defaults(for role: ControllerPointerRole) -> PointerClickBindings
}
public enum PointerOutput: Equatable, Sendable {
    case touching(Bool)
    case moved(delta: CGPoint, position: CGPoint)      // both as fractions of the screen
    case action(PointerAction, isDown: Bool)
    case recentered(position: CGPoint)
    case speedChanged(Double)
}
public struct ControllerPointerSession: Sendable {
    public static let speedStep = 0.2
    public var curve: PointerSpeedCurve
    public var bindings: PointerClickBindings
    public private(set) var cursor: PointerCursor
    public init(curve: PointerSpeedCurve, bindings: PointerClickBindings, tuning: TouchpadGestureRecognizer.Tuning = .init())
    public mutating func update(_ sample: TouchpadSample, at time: TimeInterval) -> [PointerOutput]
    public mutating func adoptCursor(_ position: CGPoint)     // another source moved the cursor
    public mutating func reset() -> [PointerOutput]            // releases held actions (`isDown: false`), forgets touch state
    public mutating func suspend()                             // forgets touch and held state, emits nothing
}
```

Policy rules: no `padHasPointerInput` → `none`; `.off` → `none`; `system == .DS` → `none`; a forced mode is honoured only if the game or core supports it, else `none`; automatic = light gun if `gameSupportsLightGun`, else mouse if `gameSupportsMouse`, else Wii pointer if `system == .Wii && coreSupportsPointer`, else `none`. Default bindings as the spec lists them (mouse: left/right zones → `leftButton`, `twoFinger` → `rightButton`; light gun: `left` → `trigger`, `right` → `reload`, `twoFinger` → `pauseMenu`; Wii: all zones → `wiiA`; none: all → `none`). `pauseMenu` emits on down only. `speedChanged` clamps to `speedRange` and updates `curve.speed`.

- [ ] **Step 1:** Write the tests: curve (`testZeroInZeroOut`, `testFullSweepAtSpeedOneCrossesScreen` with acceleration 0, `testFasterNeverTravelsLess`), cursor (`testClampsAndReportsAppliedDelta`, `testRecenter`), policy (one test per rule above, including `testDSIsAlwaysNone` and `testForcedModeNeedsSupport`), bindings (`testDefaultsPerRole`, `testCodableRoundTrip`), session (`testDragMovesCursor`, `testClickMapsThroughBindings`, `testPauseActionOnlyOnDown`, `testTwoFingerTapRecenters`, `testSlideChangesSpeedAndClamps`, `testAdoptCursorContinuesFromThere`, `testResetReleasesHeldActions`, `testSuspendDropsStateWithoutEvents`).
- [ ] **Step 2:** Run both classes; expect compile failure.
- [ ] **Step 3:** Implement the three files.
- [ ] **Step 4:** Run both classes; expect all pass.
- [ ] **Step 5:** Commit `feat(input): pointer cursor, role policy and touchpad session`.

### Task 3: Reading the pad, and the Controller Input Test screen (step 0)

**Files:**
- Create: `PVUI/Sources/PVUIBase/Controller/GCController+PointerInput.swift`
- Create: `PVUI/Sources/PVSwiftUI/Settings/Views/ControllerInputTestView.swift`
- Modify: `PVUI/Sources/PVSwiftUI/Settings/Views/ControllerSettingsView.swift` (a `NavigationLink` beside the "Help & Guides" links, around line 434)

**Interfaces (produces):**

```swift
public extension GCController {
    /// The hardware pad behind `PVPhysicalProfileController` / `PVRemappedController`, or self.
    var hardwareController: GCController { get }
    var hasTouchpad: Bool { get }                    // DualSense or DualShock 4
    var touchpadSample: TouchpadSample? { get }      // nil when the pad has no touchpad
    var isTouchpadClicked: Bool { get }
}
```

The screen lists each connected pad with: vendor name and product category; touchpad fingers as two dots in a pad-shaped box plus their numbers; click state; `motion` presence, `sensorsRequireManualActivation`, `hasAttitude`, `hasRotationRate`, `hasGravityAndUserAcceleration`; live rotation rate and acceleration; the sorted element names of `physicalInputProfile` with pressed ones highlighted. It refreshes on a `TimelineView(.animation)`, sets `motion.sensorsActive = true` in `onAppear` for pads that need it and restores the earlier value in `onDisappear`. Retrowave settings styling as the neighbouring views; tvOS focusable rows.

- [ ] **Step 1:** Implement the extension and the view, add the link titled "Controller Input Test".
- [ ] **Step 2:** `swiftlint lint --path` on the three files; fix findings.
- [ ] **Step 3:** Commit `feat(settings): controller input test screen`.

### Task 4: Pause from the touchpad click (step 1, PVUI)

**Files:**
- Modify: `PVUI/Sources/PVUIBase/Controller/PauseMenuTrigger.swift`, `PauseMenuTriggerMonitor.swift`
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController.swift` (`startPauseTriggers`, around line 1370)
- Test: `PVUI/Tests/PVUIBaseTests/PauseMenuTriggerTests.swift`

**Interfaces (consumes Task 2, Task 3; produces):**

```swift
case touchpadButton                                   // PauseMenuTrigger; hint "Press the touchpad to open the pause menu"
PauseMenuPadCapabilities.hasTouchpadButton: Bool      // new init parameter, default false
PauseMenuButtonSample.touchpadButton: Bool            // new init parameter, default false
static func plan(for pad: PauseMenuPadCapabilities, systemUsesSelect: Bool, touchpadIsFree: Bool = false) -> PauseMenuBindingPlan
PauseMenuTriggerMonitor.init(systemUsesSelect:controllers:touchpadIsFree: @escaping (GCController) -> Bool = { _ in false }, onTrigger:)
extension PVEmulatorViewController { var controllerPointerRole: ControllerPointerRole { get }; func touchpadIsFree(on controller: GCController) -> Bool }
```

`.touchpadButton` goes first in the plan when `hasTouchpadButton && touchpadIsFree`; the rest of the plan is unchanged. The monitor evaluates `touchpadIsFree` every tick and rebuilds that pad's detector when the answer changes (a fresh detector's first sample only records). `touchpadIsFree(on:)` is `controllerPointerRole == .none` and no `ControllerMappingStore` destination for `.touchpadButton` under the pad's vendor name. `controllerPointerRole` comes from `ControllerPointerPolicy` with the core's `MouseResponder` / `LightGunResponder` answers and mode `.automatic` until Task 7 supplies the stored mode.

- [ ] **Step 1:** Add to `PauseMenuBindingPolicyTests`: `touchpadTriggerLeadsWhenFree` (DualSense capabilities, Select system: `[.touchpadButton, .thumbstickChord, .startSelectChord]`), `touchpadTriggerLeavesWhenNotFree`, `padWithoutTouchpadIsUnchanged`. Add to `PauseMenuTriggerDetectorTests`: `touchpadClickFiresOnPressEdge`, `touchpadHeldAtStartDoesNotFire`.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Commit `feat(input): open the pause menu from the touchpad click`.

### Task 5: Create is Select on every native core (step 1, ObjC)

**Files:**
- Modify: `PVCoreObjCBridge/Sources/PVCoreObjCBridge/include/PVCoreObjCBridge/PVControllerButtonUtils.h` (`PVResolveStartSelectShareButtons`, PlayStation branch, and its doc comment; the "Touchpad Button Detection" comment)
- Modify: `Cores/Mednafen/Sources/MednafenGameCoreBridge/MednafenGameCoreBridge+Controls.mm:1233-1234` and `:1448-1449` (PC Engine)

PlayStation branch becomes: Start = `buttonMenu`; Select = `buttonOptions`, falling back to the share-like profile button. The touchpad click is no longer read. Mednafen PC Engine: Select = `buttonOptions`, Run = `PVStartButtonForController(controller)` falling back to what it reads today on pads where that is nil. Then `git grep -n touchpadButton -- 'Cores/*' ':!Cores/Dolphin/dolphin-ios' ':!Cores/Azahar/azahar' ':!Cores/emuThree/emuthree' ':!Cores/PPSSPP/ppsspp'` must show no game-button use.

- [ ] **Step 1:** Make the edits.
- [ ] **Step 2:** Build check: `xcrun clang -fsyntax-only` is not practical for these bridges; build the Mednafen package scheme for the iOS simulator (it includes the header) and restore any `Package.resolved` it rewrites.
- [ ] **Step 3:** Commit `fix(input): Create is Select on PlayStation pads in native cores`.

### Task 6: One mouse route (step 2, cores and router)

**Files:**
- Modify: `PVCoreBridge/Sources/PVCoreBridge/Features/Controls.swift` (`MouseResponder`)
- Modify: `PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Controls.swift` (add the delta method beside `mouseMoved(atPoint:)`; delete the touchpad block at 375-428 and its `_padTouchPrev*` state)
- Modify: `Cores/snes9x/PVSNES/SNES/PVSNESEmulatorCore.swift`
- Modify: `PVUI/Sources/PVUIBase/Controller/PVRemappableController.swift` (delete `forwardTouchpadMotionAsMouseDelta`, `forwardTouchpadButtonAsMouseClick`, `currentMouseCore` and their state; the touchpad click stays a remap source; the `touchpadPrimary` handler goes)
- Create: `PVUI/Sources/PVUIBase/Controller/ControllerPointerRouter.swift`
- Create: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController+PointerOverlay.swift`
- Modify: `PVUI/Sources/PVUIBase/PVEmulatorVC/PVEmulatorViewController.swift` (start/stop beside the pause triggers; `controllerPointerRole` now reads the router)
- Test: `PVCoreBridgeRetro/Tests/PVLibRetroTests/RelativeMouseScalerTests.swift`

**Interfaces (consumes Tasks 2-4; produces):**

```swift
// MouseResponder
@objc optional func mouseMoved(byNormalizedDelta delta: CGPoint)   // fraction of the emulated screen, same on iOS and tvOS

@MainActor final class ControllerPointerRouter {
    init(host: PVEmulatorViewController)
    private(set) var role: ControllerPointerRole
    func start(); func stop()
    func refreshRole()                 // game start, virtual mouse / light gun toggled, setting or remap changed
}
extension PVEmulatorViewController {
    var pointerRouter: ControllerPointerRouter? { get set }      // associated object, as the other extensions do
    func installPointerOverlayIfNeeded(); func removePointerOverlay()   // cross-platform arrow host
}
```

Thin: `mouseMoved(byNormalizedDelta:)` runs the delta through `_mouseScaler.units` with `relativeMouseScale()` and calls `_bridge.setMouseDeltaX`; DS ignores it. snes9x: `snesMouseMoved(byDelta:)` with the delta times 256 × 224. Router tick: skip unless the app is active and `host.isShowingMenu` is false (on the edge into either, `session.suspend()`); pick the pad (player 1's if it has a touchpad, else the first that has); `refreshRole()` result `.none` means no session and no sink; feed `pad.touchpadSample` to `ControllerPointerSession`; for `.mouse` map `moved` to `mouseMoved(byNormalizedDelta:)` (fallback `mouseMoved(atPoint: position)` on iOS when the core lacks it), `action(.leftButton/.rightButton)` to the down/up calls, `action(.pauseMenu, true)` to `PauseMenuTrigger.touchpadButton.postPauseRequest()`, and post `.PVMousePositionDidChange` for `moved` and `recentered`; a remapped `.touchpadButton` suppresses all `action` outputs. Observe `.PVMousePositionDidChange` from other senders (`object !== self`) and call `adoptCursor`. On stop, pad loss or role change, deliver `session.reset()`. Sinks for `.wiiPointer` and `.lightGun` arrive with the second plan; until then the router reports `.none` for those roles, so the touchpad click stays the pause button in Wii and gun games.

The overlay host reuses `cursorHostingController` when the iOS virtual mouse installed one; otherwise (tvOS, or iOS with no virtual mouse) it hosts a `MouseCursorOverlayView` sized to `currentTargetFrame` or the GPU view's frame and keeps it in step from `viewDidLayoutSubviews`.

- [ ] **Step 1:** Add `normalizedDeltaScalesBySweep` to `RelativeMouseScalerTests` (delta 0.5 at scale 640 × 400 gives 320 and 200 units; a run of sub-unit deltas loses nothing).
- [ ] **Step 2:** Implement the protocol member, thin and snes9x.
- [ ] **Step 3:** Implement the router, overlay host and wiring; delete the two old routes.
- [ ] **Step 4:** `swiftlint` the changed Swift files; run the PVCoreBridge classes from Tasks 1-2 again.
- [ ] **Step 5:** Commit `feat(input): one touchpad mouse route for every mouse core`.

### Task 7: Options (step 2)

**Files:**
- Create: `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/ControllerPointerSettings.swift`
- Modify: `PVUI/Sources/PVUIBase/Controller/ControllerPointerRouter.swift`, `PVUI/Sources/PVUIBase/PVEmulatorVC/PauseTileMenuViewModel.swift`, `PauseTileMenuView.swift` (mouse tiles), `PVUI/Sources/PVSwiftUI/Settings/Views/MouseInputSettingsView.swift`, `PVSettings/Sources/PVSettings/Settings/Model/PVSettingsModel.swift` (comments only: the keys are now read)
- Test: `PVCoreBridge/Tests/PVCoreBridgeTests/ControllerPointerSettingsTests.swift`

**Interfaces (produces):**

```swift
public struct ControllerPointerSettings: Codable, Equatable, Sendable {      // nil = inherit
    public var mode: ControllerPointerMode?
    public var speed: Double?
    public var acceleration: Double?
    public var bindings: [ControllerPointerRole: PointerClickBindings]?
    public init(); public var isEmpty: Bool { get }
}
public enum ControllerPointerScope: Hashable, Sendable {
    case global, system(SystemIdentifier), game(md5: String)
    public var key: String { get }          // "global", "system:<id>", "game:<md5>"
}
public final class ControllerPointerSettingsStore: @unchecked Sendable {
    public static let shared: ControllerPointerSettingsStore
    public static let didChangeNotification: Notification.Name
    public init(defaults: UserDefaults = .standard)
    public func settings(for scope: ControllerPointerScope) -> ControllerPointerSettings
    public func update(_ scope: ControllerPointerScope, _ change: (inout ControllerPointerSettings) -> Void)
    public struct Resolved: Equatable, Sendable { mode; curve: PointerSpeedCurve; func bindings(for role:) -> PointerClickBindings }
    public func resolved(system: SystemIdentifier?, gameMD5: String?) -> Resolved
}
```

Resolution is field by field, game then system then global. The global scope's speed is `Defaults[.mouseSensitivity]`; its mode maps from `Defaults[.mouseInputSource]` (`touchscreen` and `physicalMouse` → `.off` for the pad, the rest → `.automatic`). The router reads `resolved` on `refreshRole()` and on the store's notification; a `speedChanged` output writes the game scope (global when there is no MD5) and shows `PVToastManager` text "Pointer speed 1.4×"; `recentered` needs no text. Pause tiles: the existing sensitivity tile steps and writes through the store for the running game; add "Recenter Pointer" and "Pointer Acceleration" tiles shown when the router's role is not `.none`. `MouseInputSettingsView`: remove the "not yet applied" note from the parts that now work (speed, input source); the gyro note stays until the second plan.

- [ ] **Step 1:** Write `ControllerPointerSettingsTests`: `testEmptyResolvesToDefaults`, `testGameBeatsSystemBeatsGlobal` (field by field), `testUpdatePrunesEmptyEntries`, `testScopeKeys`, `testGlobalSpeedComesFromMouseSensitivity` (injected defaults suite).
- [ ] **Step 2:** Run; expect compile failure. Implement. Run; expect pass.
- [ ] **Step 3:** Wire the router, tiles and settings view; `swiftlint`.
- [ ] **Step 4:** Batch check: PVUI `PauseMenuBindingPolicyTests`, `PauseMenuTriggerDetectorTests`, `MouseCursorOverlayTests`; PVLibRetro `RelativeMouseScalerTests`.
- [ ] **Step 5:** Commit `feat(input): touchpad pointer speed, recenter and per-game settings`; update the side-session notes and the hardware checklist.

## Hardware checklist for this plan (owner, one device run)

1. Controller Input Test: finger up reads 0, 0; second finger appears; click toggles; motion flags and values for each pad.
2. DualSense on NES (native) and SNES: the touchpad click opens and closes the menu; Create is Select; Options is Start.
3. Mario Paint (snes9x native) and a DOS or Amiga game (thin): the touchpad moves the cursor at a sane speed, click and two-finger click work, two-finger tap recenters, two-finger slide changes speed.
4. The same on tvOS, where the arrow cursor must be visible.
