# Controller touchpad and gyro: pause, mouse, Wii pointer, light gun

Date: 2026-11-11. Status: approved by the owner 2026-11-11.

## Why

A DualSense or DualShock 4 has a touchpad, a touchpad click and motion sensors. Provenance uses almost
none of it, and what it does use is wrong:

- The touchpad-as-mouse route added in `ad51998c96` (`PVRemappableController.forwardTouchpadMotionAsMouseDelta`)
  sends movement deltas into `MouseResponder.mouseMoved(atPoint:)`, which cores on iOS read as an absolute
  0-1 position. On native snes9x the cursor barely moves. The thin wrapper has a second, polled route
  (`PVThinLibretroCore+Controls.swift:375`) that works on its own, and both run at once.
- The gyro mouse, "Input Source" and "Mouse Sensitivity" settings are stored and never read.
  `GyroMouseAdapter` has tests and no caller, and never sets `GCMotion.sensorsActive`.
- No light gun can be aimed from a controller. Dolphin's Wii pointer cannot be driven from a pad except by
  the on-screen stick.
- Since `1890a49971` a PlayStation pad has no single free button for the pause menu on systems that use
  Select, and on native FCEU, Gambatte and TGBDual its Create button does nothing at all (Select is the
  touchpad click there).

The audit behind this is summarised in "Current state" below.

## What the owner asked for

In the owner's words, confirmed in conversation on 2026-11-11:

- Gyro and touchpads on external controllers should work. "They should report motion right? Makes sense if
  it's being mapped."
- The touchpad press can open the menu when the touchpad is not used for touch.
- For Wii, the touchpad is the IR cursor; for SNES and other mouse systems, it is a mouse.
- A drag-and-press light gun with on-screen indicators while touching, so the player knows where they aim.
- Left/right touchpad press for other things, such as reload.
- Speed should be usable out of the box, with user options, a way to recenter, and on-the-fly speed or
  acceleration changes from the pause menu or with two-finger gestures on the pad.
- Profiles and custom mappings for all of this.
- Pause: "pause is a nightmare, just make it work well." The pause decisions below are therefore the
  builder's call, not the owner's.
- Build order, approved: pause, mouse, Wii pointer, light gun, gyro and profiles.
- Added after approval, same day: "Wii shake/tilt would be really nice. Shake is probably most important
  because Mario Wii uses that mechanic a ton." And: are the trigger feedback APIs used, "like virtual click
  for GameCube, R or Z, that has a double trigger action"? Both are now in scope (steps 4 and 7). The
  builder placed shake and tilt straight after the Wii pointer.

## Goals

1. On a PS4 or PS5 pad the touchpad click opens the pause menu on every system, unless the running game is
   using the touchpad as its pointer. Create is Select on every core.
2. One correct touchpad-as-mouse route for every mouse-capable core, with speed, acceleration, recenter and
   right-click, adjustable from the pause menu and from the pad.
3. The touchpad drives the Wii pointer in Dolphin.
4. The touchpad aims a light gun on every light-gun core, with a crosshair and a fire/reload split by where
   the pad is pressed.
5. Gyro can drive the same pointer in all three roles (step 6). The existing gyro and mouse settings do what they say.
6. Pointer settings resolve per game, then per system, then globally.
7. Shaking or tilting a pad that has motion sensors shakes or tilts the Wii Remote in Dolphin.
8. GameCube L and R are analog from the pad's triggers with the digital click at the end of travel, and a
   DualSense makes that click point felt.

## Non-goals (this pass)

- Two-finger gestures outside pointer games (fast-forward, rewind).
- 3DS motion from a pad's sensors, and Wii MotionPlus (raw gyro) data. The motion protocol leaves room.
- The touchpad as a DS or 3DS stylus. The pointer protocol below leaves room for it.
- Aiming from an analog stick (Xbox pads have neither touchpad nor gyro). The source enum leaves room.
- A second player's pointer. Player 1's pad only.
- Storing pointer settings inside the Realm `PVControllerProfile` (no schema change now).
- PS2 and PS3 pads: iOS and tvOS do not pair them.
- A Bluetooth mouse on tvOS; Dolphin's uncalled touch-screen pointer methods.

## Anti-goals

- No new `valueChangedHandler` or `pressedChangedHandler` on a controller element. Those slots are single,
  and Dolphin, PPSSPP, emuThree and the remap pipeline already overwrite each other. Everything here samples
  state on the display refresh, as `PauseMenuTriggerMonitor` does.
- A press that reaches the game never also opens the menu, and the reverse.
- The cursor never jumps when a finger lands or lifts.
- No per-core copies of logic a shared layer can hold.
- Nothing that needs a trip to Settings before it feels right.

## Constraints

- iOS 17+ and tvOS 17+; every file compiles for both (guards where an API is missing).
- `SystemIdentifier`, never raw system strings.
- Decision logic is pure, lives in PVCoreBridge and is unit tested there (the PVCoreBridge test run takes
  about a minute; PVUI's takes many).
- Nothing in this area has been tried on a physical controller. Each step ends with a short hardware
  checklist; the test screen in step 0 exists to make that one quick run.

## Current state

| Path | State |
|---|---|
| Gyro mouse settings, `GyroMouseAdapter` | Setting only; adapter unused |
| Mouse "Input Source", "Mouse Sensitivity" | Setting only |
| Touchpad to mouse, thin wrapper poll | Works in code; thin cores, player 1, no click |
| Touchpad to mouse, `PVRemappableController` | Broken (deltas sent as positions); click as left button works |
| Touchpad click | Remappable button; the only Select on PS pads in native FCEU, Gambatte, TGBDual |
| Mouse hardware, touch trackpad, touch light gun | Finished on iOS |
| Light gun from a pad; Wii pointer from a pad | Absent |

`MouseResponder.mouseMoved(atPoint:)` means an absolute 0-1 position on iOS and a per-event delta in view
points on tvOS (thin and snes9x have `#if os(tvOS)` branches). New code must not add a third meaning.

## Design

### Pieces

**Pure logic, PVCoreBridge `Features/ControllerPointer/`** (all `Sendable` value types, no GameController
imports in the logic itself, unit tested):

- `TouchpadSample`: first and second finger positions (nil when that finger is up) and whether the pad is
  clicked. GameController reports a lifted finger as exactly (0, 0); the reader turns that into nil.
- `TouchpadGestureRecognizer`: `mutating update(_ sample:, at time:) -> [TouchpadEvent]`. Events:
  one-finger movement (delta in pad units; the first sample after a finger lands gives none), one-finger
  position, click down/up with a zone (`left`, `right`, `twoFinger`), two-finger tap, two-finger vertical
  slide. Zone is the first finger's side at press time; with no finger reading it is `left`.
  Two-finger rules: while two fingers are down the cursor does not move. A click with two fingers down is a
  two-finger click and cancels any tap or slide in progress. A slide is both fingers moving the same way
  vertically past a threshold with no click. A tap is two fingers down and up quickly, with little movement
  and no click.
- `PointerSpeedCurve`: speed (0.1-5.0) and acceleration (0-1) applied to a delta and its velocity. Zero in
  gives zero out; faster movement never gives less travel.
- `PointerCursor`: an absolute 0-1 cursor with `apply(delta)`, `set(position)`, `recenter()`. Returns the
  clamped position and the delta actually applied.
- `ControllerPointerRole`: `none`, `mouse`, `wiiPointer`, `lightGun`.
- `ControllerPointerPolicy.role(for:setting:)`: from what the running game supports and the user's mode.
  Automatic order: light gun (the game is a gun game), then mouse (the game supports a mouse), then Wii
  pointer (the system is Wii), else none. Nintendo DS is always `none` in this pass.
- `PointerClickBindings`: zone to action, per role. Defaults:
  - mouse: one-finger click = left button, two-finger click = right button;
  - light gun: left half = trigger, right half = reload, two-finger click = pause menu;
  - Wii pointer: left half = Wiimote A, right half = Wiimote B, two-finger click = pause menu (changed
    2026-11-12 while building: with the touchpad taken, a PlayStation pad has no other single pause button
    in Wii games, and pointer shooters need B).

  Actions a zone can be bound to: left button, right button, trigger, reload, aux A, aux B, gun Start,
  Wiimote A, Wiimote B, pause menu, nothing.
- `ControllerPointerSettings` and its scope resolution (see "Settings and profiles").
- `GyroPointerFilter`: the dead zone, low-pass and time-step maths lifted out of `GyroMouseAdapter`, with its
  tests. `GyroMouseAdapter` is deleted once nothing else uses it.

**Protocols, PVCoreBridge `Features/Controls.swift`:**

- `MouseResponder` gains `@objc optional func mouseMoved(byNormalizedDelta delta: CGPoint)`: a movement as a
  fraction of the emulated screen, the same on iOS and tvOS. Implemented by the thin wrapper (scaled by its
  existing `relativeMouseScale()`) and native snes9x. For a core without it the router falls back to
  `mouseMoved(atPoint:)` with the absolute cursor on iOS and sends nothing on tvOS (Atari800 and ep128 only).
- New `@objc protocol PointerResponder`: `gameSupportsPointer`, `pointerMoved(toNormalizedPoint:forPlayer:)`,
  `pointerLeftScreen(forPlayer:)`, and optional button calls for the pointer's primary button. Dolphin's
  bridge conforms: it writes IR axes 112-115 as `updateIRCursorWithLocation` does (honouring `rotateIr` and
  the multiplayer port offset) and resets them when the pointer leaves.

**Runtime, PVUIBase `Controller/ControllerPointerRouter.swift`** (`@MainActor`, one per running game, started
and stopped beside `startPauseTriggers()` / `stopPauseTriggers()`, ticking on an `OwnedDisplayLink`):

1. Picks the pointer pad: player 1's controller if it has a touchpad (`GCDualSenseGamepad`,
   `GCDualShockGamepad`) or, from step 4, motion; otherwise the first connected pad that has. Wrappers
   (`PVRemappedController`, `PVPhysicalProfileController`) are unwrapped to the hardware pad. Whichever pad
   it is, the pointer belongs to player 1's port.
2. Reads `touchpadPrimary`, `touchpadSecondary` and `touchpadButton.isPressed` into a `TouchpadSample`.
3. Runs the recognizer, the speed curve and the cursor.
4. Delivers to the sink for the current role (below) and posts the notifications the on-screen cursor and
   crosshair already listen to (`.PVMousePositionDidChange`, `.lightGunCursorDidMove`).
5. Stops delivering while the pause menu is open or the app is not active.

The role is recomputed when the game starts, when the player toggles the virtual mouse or light gun in the
pause menu, and when a pointer setting changes.

One cursor per game. A hardware mouse, the touch trackpad and the touch light gun keep working beside the
pad and are not suppressed. When one of them posts a cursor or aim position, the router adopts it as its own
cursor, so the pad's next drag continues from there and the arrow or crosshair has one position.

A player's own remap of `ButtonIdentifier.touchpadButton` wins over every click binding here, in every role:
the click does what they mapped, and the pointer still moves.

### Step 0: controller test screen

Settings → Controllers → "Controller Input Test": for each connected pad, live touchpad finger positions,
click, motion rotation rate and gravity, whether the pad needs its sensors switched on, and the element
names in its physical input profile. It switches sensors on while it is on screen. One run on a device with
each pad answers the hardware unknowns listed at the end. It stays in the app.

### Step 1: pause from the touchpad click, Create as Select

- `PauseMenuTrigger` gains `.touchpadButton`; `PauseMenuPadCapabilities` gains `hasTouchpadButton`;
  `PauseMenuButtonSample` gains `touchpadButton`. `PauseMenuBindingPolicy.plan` takes `touchpadIsFree` and
  puts `.touchpadButton` first when the pad has one and it is free. The other triggers stay as backups.
- The touchpad is free when the pointer role is `none` and the player has not remapped
  `ButtonIdentifier.touchpadButton` to something. A remap wins: the click does what they mapped.
- `PauseMenuTriggerMonitor` rebuilds a pad's detector when "free" changes, and the hint toast gets a line
  for the new trigger.
- `PVResolveStartSelectShareButtons` (PVControllerButtonUtils.h): on PlayStation pads Select becomes
  `buttonOptions` (Create/Share), not the touchpad click. That covers FCEU, Gambatte, TGBDual and Mednafen
  NES. Mednafen's PC Engine mapping reads `touchpadButton` as Select directly and changes the same way.
  Any other native bridge that reads the touchpad click as a game button is brought into line.
- Cost, accepted by the builder: players used to touchpad-click-as-Select on those cores lose it.
- While the touchpad is a pointer, the click belongs to the game. The menu then opens from: Create on
  systems without Select (Wii included); the two-finger click in gun games; and L3+R3 or Create+Options
  everywhere, which is all a PS pad has in a mouse game on a system that uses Select. The hint toast names
  whichever applies. On iOS the on-screen menu button is also there.
- Reaches: every core, since the monitor samples the pad itself.

### Step 2: touchpad as mouse

- The router's `mouse` sink calls `mouseMoved(byNormalizedDelta:)`, `leftMouseDown/Up`, `rightMouseDown/Up`.
- Removed: the thin wrapper's own touchpad block (`PVThinLibretroCore+Controls.swift:375-428`) and
  `PVRemappableController`'s `forwardTouchpadMotionAsMouseDelta` / `forwardTouchpadButtonAsMouseClick`. The
  touchpad click stays a remappable source there.
- Relative movement: dragging moves the cursor from where it is, like a laptop trackpad.
- Two-finger tap recenters. Two-finger slide up or down changes speed in steps, shows a short on-screen
  readout ("Pointer speed 1.4×") and saves to the game's settings.
- Pause-menu tiles (Controls group): pointer speed down/up, acceleration, recenter, pointer mode. The
  existing "Mouse Sensitivity" and "Input Source" tiles and settings are wired to the same values:
  `mouseSensitivity` is the global pointer speed; `mouseInputSource` picks touchpad, gyro, hardware mouse or
  touch, with Auto meaning "every source that is present".
- The arrow cursor overlay must appear when a pad drives the pointer, including on tvOS and when a
  connected controller hides the skin. Today it is installed only by the iOS-only virtual mouse file. Its
  hosting moves into a small cross-platform piece the router asks for; `MouseCursorOverlayView.systemDrawsOwnPointer`
  still decides whether to draw the arrow.
- Reaches: every libretro mouse game on the thin wrapper (the systems in `MouseGameRegistry`, DS excluded),
  native snes9x, and by fallback the deprecated Atari800 and ep128 on iOS.

### Step 3: Wii pointer

- Role `wiiPointer` whenever the system is Wii and the pad has a touchpad. The sink is `PointerResponder`.
- Relative by default (drag moves the pointer; the game draws it). "Pad is the screen" (absolute) is an
  option, because some players will prefer it for menus.
- Left click is Wiimote A, right click Wiimote B, two-finger click the pause menu (see the defaults above).
- The stick-to-IR path and its option are untouched.
- Reaches: Dolphin only.

### Step 4: Wii shake and tilt

Today Dolphin's bridge shakes the Wii Remote from buttons: R2 sends Shake Y, and the A, X and other face
handlers send Shake axes along with their button (`PVDolphinCore+Controls.mm:366-432`). Its device-motion
code, including a shake detector, never runs because motion is never started (`:1693`).

- `ControllerMotionSource` (PVUIBase) arrives here rather than in the gyro step: it sets
  `motion.sensorsActive = true` on pads where `sensorsRequireManualActivation` is true while a game uses
  motion, samples acceleration and rotation rate on the router's tick, and switches the sensors off when the
  game pauses or ends.
- Pure logic in PVCoreBridge: `ShakeDetector` (acceleration samples in, "shaking" out, held for a short
  minimum so one flick registers as one shake) and `TiltEstimator` (low-passed gravity to pitch and roll).
  Pads report total acceleration, so both work from that and do not need a gravity/user split.
- New `@objc protocol MotionResponder` in PVCoreBridge: `gameSupportsMotion`,
  `motionShakeChanged(_ shaking: Bool, forPlayer:)`, `motionTiltChanged(pitch:roll:forPlayer:)`. Dolphin's
  bridge conforms: shake drives the Wii Remote's Shake X/Y/Z inputs (132-134), tilt drives its Tilt axes.
- The button-driven shakes stay as they are (a pad without sensors still needs them). Whether the face
  buttons should keep sending shake once real shake works is a question for the hardware run, not decided here.
- Dolphin's existing options "Enable Gyro Motion Controls" and "Enable Gyro IR Cursor" gate this and step 6's
  gyro pointer for Wii. An iPhone or iPad with no motion-capable pad feeds the same two detectors from its
  own sensors, replacing the dead CoreMotion code.
- Reaches: Dolphin (Wii) only. Pads: DualSense, DualShock 4, and Switch Pro / Joy-Con if they report
  motion; Xbox pads have no sensors and keep shake on R2.

### Step 5: light gun

- Role `lightGun` when `gameSupportsLightGun`. The sink calls `lightGunMovedToPoint(_:isOffscreen:)`,
  trigger, reload (which the cores already treat as an off-screen shot), aux A.
- "Drag and press": dragging moves the crosshair, pressing the left half fires, pressing the right half
  reloads. Absolute aiming is the same option as in step 3.
- On-screen indicator: the existing crosshair (styles from `LightGunCrosshairStyle`, per-game override) is
  always drawn in gun games when a pad is the gun, and gains a ring while a finger is on the pad. Like the
  arrow in step 2 it must not depend on the skin being visible, and must exist on tvOS.
- R2 also fires and L2 also reloads while the role is `lightGun`, read by sampling, so the gun works with
  the pad held normally.
- Reaches: FCEU, snes9x (Super Scope, Justifier), Genesis Plus GX, Mednafen (Saturn, PSX GunCon, NES,
  legacy SNES), Stella, ProSystem, and thin-wrapper light-gun games per `LightGunGameRegistry`.

### Step 6: gyro aiming, then profiles

- Uses step 4's `ControllerMotionSource`, which now also runs while a pointer role uses gyro. On an iPhone
  or iPad with no motion-capable pad it can use the device's own sensors, as `GyroMouseAdapter` intended.
- Gyro feeds the same `PointerCursor` through `GyroPointerFilter`, so it works in all three roles. With
  touchpad and gyro both on, movements add.
- `gyroMouseEnabled`, `gyroMouseSensitivity` and `gyroMouseDeadZone` become live, and the "stored but not yet
  applied" note in `MouseInputSettingsView` goes.
- Recenter for gyro: two-finger tap on PS pads. A pad with no touchpad recenters from the pause-menu tile
  only: cores read its buttons directly, so no button can be taken from the game for this. Pushing the
  cursor against a screen edge also re-aligns it, as the cursor is clamped.

### Step 7: GameCube triggers

Today Dolphin's bridge reads L2/R2 as pressed or not and sends the GameCube trigger axis as 0 or 1
(`PVDolphinCore+Controls.mm:409-450`), so a half pull (Super Mario Sunshine's spray, Luigi's Mansion) cannot
be done. DualSense adaptive triggers are already driven by `GCControllerHapticsManager`, but only a soft
resistance for PlayStation systems.

- The GameCube trigger axes follow the pad's analog trigger value. The digital L/R click is sent when the
  value passes a threshold near the end of travel (0.9 to start; tuned on hardware). The existing
  both-triggers-for-Z rule keeps working from the same values.
- `GCControllerHapticsManager` gains a `.gameCubeClick` profile used for GameCube: resistance that gives way
  at the click point, so the analog range and the click feel like two stages. Its system matching moves to
  `SystemIdentifier` while it is being touched. The existing "DualSense adaptive triggers" setting gates it.
- Reaches: Dolphin (GameCube) only. Every pad gets analog triggers; only a DualSense gets the felt click.

### Settings and profiles

`ControllerPointerSettings` (PVSettings, `Codable`, every field optional = inherit): mode (automatic, off,
mouse, Wii pointer, light gun), sources (touchpad, gyro), speed, acceleration, aim style (relative,
absolute), invert Y, click bindings. Stored in `Defaults` as one dictionary keyed by scope, using the scope
strings `ShaderLibraryStore` uses (`global`, `system:<id>`, `game:<md5>`), resolved field by field, game
first. Pause-menu tiles and pad gestures write the game scope. Settings → Controllers gets a
"Touchpad & Motion" section for the global and per-system values, with the click bindings editable there.
The existing global keys (`mouseSensitivity`, `gyroMouse*`, `mouseInputSource`) are the global scope's
storage, so nothing migrates. The dictionary is local to the device in this pass (no iCloud sync), and a
game whose MD5 changes loses its per-game values, as per-game light-gun settings already do.

## Calls the builder made (owner to check)

1. Touchpad click opens the menu on PS pads; Create becomes Select on every core; the touchpad click stops
   being Select on native NES, Game Boy and PC Engine.
2. In a mouse game on a system that uses Select, a PS pad opens the menu with L3+R3 or Create+Options only.
3. In gun games: left half fires, right half reloads, two-finger click opens the menu, R2 fires, L2 reloads.
4. Mouse games: one-finger click is the left button, two-finger click the right button.
5. Wii: click is Wiimote A; pointer is relative by default, with "pad is the screen" as an option.
6. Two-finger tap recenters; two-finger slide changes speed and saves it for that game.
7. A player's own remap of the touchpad click always wins.
8. The pointer is player 1's, driven by player 1's pad or else the first pad with a touchpad.
9. Pad sensors are on only while a game uses motion.
10. A "Controller Input Test" screen is built first and stays in the app.
11. Pointer settings are per game, per system and global, stored on the device, not in the Realm controller
    profiles and not synced.
12. Wii shake and tilt come straight after the Wii pointer; the buttons that shake today keep doing so.
13. GameCube L/R click at 90% of trigger travel until a hardware run says otherwise.

## Which cores each step reaches

| Step | Thin wrapper | Native |
|---|---|---|
| 1 pause, Select | all | all; Select change in FCEU, Gambatte, TGBDual, Mednafen |
| 2 mouse | all mouse games except DS | snes9x; Atari800, ep128 by fallback (iOS) |
| 3 Wii pointer | none | Dolphin |
| 4 Wii shake, tilt | none | Dolphin |
| 5 light gun | libretro light-gun games | FCEU, snes9x, Genesis Plus GX, Mednafen, Stella, ProSystem |
| 6 gyro aiming | as steps 2 and 5 | as steps 2, 3 and 5 |
| 7 GameCube triggers | none | Dolphin |

## Tests

- PVCoreBridge: recognizer (finger down/up produce no delta, zones, two-finger tap and slide, a two-finger
  click that moves, click with no finger), speed curve, shake detector, tilt estimator, cursor clamping and recenter, role policy for each system kind and mode, click
  bindings, settings resolution across scopes, gyro filter (moved from the adapter's tests).
- PVUI: pause policy with the touchpad trigger (free, pointer in use, remapped), detector edge on the click.
- Thin wrapper (PVLibRetroTests): `mouseMoved(byNormalizedDelta:)` scaling per system.
- The ObjC Select helper has no test target; it is checked by building the four cores that include it.

## Only a physical pad can confirm

- That a lifted finger reads exactly (0, 0) and a resting one never does.
- Touchpad speed and acceleration defaults; whether the second finger is reported reliably enough for the
  two-finger tap and slide.
- That DualSense, DualShock 4 and Switch Pro report motion once sensors are on, and at what rate.
- The pause triggers from `1890a49971`, and the name of the Switch Pro Capture button.
- That the system does not also act on the touchpad click or Create (screenshot, clip) once the app reads them.
- Shake and tilt thresholds, and whether face buttons should stop sending shake once real shake works.
- Where the GameCube click should sit and how the DualSense trigger resistance feels there.

## Left to the builder

File layout inside the folders named above, curve constants, slide step size, the readout's look, tile
icons and wording, and how the router and the pause monitor share one display link.
