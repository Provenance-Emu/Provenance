# Wii pointer and shake from a pad: implementation plan

> For agentic workers: steps use checkbox (`- [ ]`) syntax. Executed natively in the session that wrote it.

**Goal:** a PS4/PS5 pad's touchpad aims the Wii Remote pointer, and shaking any pad shakes that player's Wii Remote.

**Architecture:** two core-facing protocols in PVCoreBridge (`PointerResponder`, `MotionResponder`), a pure
`ShakeDetector`, and two sinks in PVUIBase. `ControllerPointerRouter` gets a Wii sink. A new
`ControllerMotionRouter` samples every pad's motion on a display link. Dolphin implements both protocols
on its existing IR axes (112-115) and shake buttons (132-134).

**Spec:** `docs/superpowers/specs/2026-11-11-controller-touchpad-gyro-design.md`, steps 3 and 4.

## Global constraints

- iOS 17+ / tvOS 17+; PV* packages also compile for macOS and visionOS (guards, not availability checks).
- `SystemIdentifier` enum, never raw `com.provenance.*` strings.
- No element handlers on controllers: sample on `OwnedDisplayLink` (single handler slots are already contended).
- Per-core mapping stays in the core's bridge (`PVDolphinCore+Controls.mm`).
- Unit tests for decision logic (XCTest in PVCoreBridgeTests).

## Review focus

1. A pad held still on a table or in the hand never shakes (gravity alone is about 1 g).
2. A continuous shake holds Shake down, not a stutter of presses (zero crossings mid-shake).
3. The first motion sample after start never fires (no gravity estimate yet).
4. Pausing or backgrounding lets go of Shake and the Wii A button.
5. Sensors switched on for the game are switched off again when it ends, and only if this code switched them on.

---

### Task 1: `ShakeDetector` (PVCoreBridge)

**Files:** create `PVCoreBridge/Sources/PVCoreBridge/Features/ControllerPointer/ShakeDetector.swift`,
test `PVCoreBridge/Tests/PVCoreBridgeTests/ShakeDetectorTests.swift`.

**Produces:** `public struct ShakeDetector` with `Tuning(gravityTimeConstant: 0.4, threshold: 0.9, holdDuration: 0.15)`
(seconds, g, seconds), `init(tuning:)`, `mutating func update(acceleration: SIMD3<Double>, at time: TimeInterval) -> Bool?`
(returns the new shake state only when it changes), `mutating func reset() -> Bool?` (returns `false` if it was shaking),
`var isShaking: Bool`.

Gravity is a low-pass of the total acceleration, `k = dt / (tau + dt)`. The first sample sets gravity and returns nil.
A sample is strong when `|acceleration - gravity| >= threshold`. Shaking while the last strong sample is less than
`holdDuration` old.

- [ ] Tests: `stillPadNeverShakes` (1 g along -z for 2 s at 60 Hz), `joltStartsShake`, `shakeHoldsThroughZeroCrossings`
  (±2 g alternating every 50 ms holds `true` with no `false` until 0.15 s after the last strong sample),
  `firstSampleNeverFires` (a 3 g first sample returns nil), `slowTiltDoesNotShake` (gravity rotated 90° over 1 s),
  `resetReleases`.
- [ ] Implement, run `PVCoreBridge` tests, commit.

### Task 2: protocols and settings

**Files:** modify `PVCoreBridge/Sources/PVCoreBridge/Features/Controls.swift`, `ControllerPointerSettings.swift` and its tests.

**Produces:**
- `@objc public protocol PointerResponder { var gameSupportsPointer: Bool { get }; func pointerMoved(toNormalized position: CGPoint, forPlayer player: Int) }`.
  `position` is 0-1 across the game picture, (0.5, 0.5) the centre; `player` is 0-based.
- `@objc public protocol MotionResponder { var gameSupportsShake: Bool { get }; func setShaking(_ shaking: Bool, forPlayer player: Int) }`.
- `ControllerPointerSettings.shake: Bool?`, resolved as `Resolved.shakeEnabled` (default `true`), included in `isEmpty`.
- [ ] Test `testShakeDefaultsOnAndResolvesPerScope`. Commit with Task 1 if small.

### Task 3: Dolphin sinks

**Files:** `Cores/Dolphin/PVDolphinCore/Core/PVDolphinCore.h`, `PVDolphinCore+Controls.mm`, `PVDolphinCore.swift`.

- Bridge: `-(void)setIRPointerNormalizedX:(CGFloat)x y:(CGFloat)y forPlayer:(NSInteger)player` (inputs in -1...1,
  applies `rotateIr`, port `4 + (multiPlayer ? player : 0)`), which `updateIRCursorWithLocation:` now calls.
  `-(void)setWiimoteShaking:(BOOL)shaking forPlayer:(NSInteger)player` presses or releases buttons 132-134 on that port.
- Swift: `PVDolphinCore: PointerResponder, MotionResponder`. Both `gameSupports*` are `_bridge.isWii`.
  `pointerMoved` maps 0-1 to -1...1.
- [ ] Build `PVDolphin` through the package workspace when the slice is present; otherwise compile-check and say so.

### Task 4: Wii sink in `ControllerPointerRouter`

**Files:** `PVUI/Sources/PVUIBase/Controller/ControllerPointerRouter.swift`.

- `deliverableRoles` gains `.wiiPointer`. Context passes `coreSupportsPointer: (core as? PointerResponder)?.gameSupportsPointer`.
- `.moved` and `.recentered` call `pointerMoved(toNormalized:forPlayer: 0)`; `.wiiA` / `.wiiB` call
  `PVWiiSystemResponderClient.didPush/didRelease(.wiiA/.wiiB, forPlayer: 0)`; `.pauseMenu` as for the mouse.
- On a role change to `.wiiPointer` the pointer is sent to the centre once.

### Task 5: `ControllerMotionRouter`

**Files:** create `PVUI/Sources/PVUIBase/Controller/ControllerMotionRouter.swift`; modify
`PVEmulatorViewController+ControllerPointer.swift` (start/stop next to the pointer router).

- Active only while `(core as? MotionResponder)?.gameSupportsShake == true` and `settings.shakeEnabled`.
- Each tick, for each player 1-4 in `PVControllerManager.shared` whose `hardwareController.motion` exists: total
  acceleration (`gravity + userAcceleration` when `hasGravityAndUserAcceleration`, else `acceleration`) into that
  player's `ShakeDetector`; a change calls `setShaking(_:forPlayer: player - 1)`.
- Turns on `sensorsActive` where `sensorsRequireManualActivation`, remembers which, turns them off on stop.
- Suspends like the pointer router (menu showing, app inactive): resets detectors, releases shake.

### Task 6: verify and ship

- PVCoreBridge tests, PVUI tvOS build, PVUI iOS tests (`PauseMenu*`, `MouseCursorOverlayTests`), Dolphin build if possible.
- Commit by path, push own commits only, update the memory and the handover note.

## Left for later (not this plan)

Tilt (needs an upright / sideways choice per game, so it lands with the pointer settings screen), light gun (step 5),
gyro aiming (step 6), GameCube analog triggers (step 7).
